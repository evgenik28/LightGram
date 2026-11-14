#include "LGMediaStore.h"

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define LGMediaStoreIndexMagic 0x534d474fu
#define LGMediaStoreIndexHeaderLength 40
#define LGMediaStoreSegmentCacheSize 4
#define LGMediaStoreCopyChunk (64 * 1024)

typedef struct {
    int64_t offset;
    size_t length;
    uint8_t *bytes;
} LGMediaStorePart;

typedef struct {
    int64_t index;
    int fd;
    uint32_t stamp;
} LGMediaStoreSegment;

struct LGMediaStore {
    pthread_mutex_t lock;
    char *path;
    char *indexPath;
    int fd;
    bool transient;
    bool sequential;
    bool indexDirty;
    bool hasSegments;
    bool failed;
    bool finished;
    int64_t size;
    int64_t prefix;
    int64_t origin;
    int64_t memoryWindow;
    int64_t pendingBytes;
    int64_t farBytes;
    uint8_t *bitmap;
    size_t bitmapLength;
    LGMediaStorePart *parts;
    size_t partCount;
    size_t partCapacity;
    LGMediaStoreSegment segments[LGMediaStoreSegmentCacheSize];
    uint32_t segmentStamp;
    uint8_t *scratch;
    uint8_t *state;
    size_t stateLength;
    void *context;
    LGMediaStoreTransform transform;
    LGMediaStoreDeliver deliver;
};

static inline int64_t LGMediaStoreAlignDown(int64_t value)
{
    return value - value % LGMediaStoreBlockSize;
}

static inline int64_t LGMediaStoreMin(int64_t a, int64_t b)
{
    return a < b ? a : b;
}

static inline int64_t LGMediaStoreMax(int64_t a, int64_t b)
{
    return a > b ? a : b;
}

static inline int64_t LGMediaStoreBlockCount(int64_t length)
{
    return length / LGMediaStoreBlockSize + (length % LGMediaStoreBlockSize != 0 ? 1 : 0);
}

static inline int64_t LGMediaStoreBlockOffset(int64_t block, int64_t endBlock, int64_t limit)
{
    if (block >= endBlock)
        return limit;
    return LGMediaStoreMin(block * LGMediaStoreBlockSize, limit);
}

static inline int64_t LGMediaStoreBlockLength(const LGMediaStore *store, int64_t block)
{
    int64_t start = block * LGMediaStoreBlockSize;
    if (store->size > 0)
        return LGMediaStoreMin(LGMediaStoreBlockSize, store->size - start);
    return LGMediaStoreBlockSize;
}

static bool LGMediaStoreEnsureBitmap(LGMediaStore *store, int64_t blockCount)
{
    size_t length = (size_t)((blockCount + 7) / 8);
    if (length <= store->bitmapLength)
        return true;
    size_t capacity = store->bitmapLength == 0 ? 64 : store->bitmapLength;
    while (capacity < length)
        capacity *= 2;
    uint8_t *bitmap = (uint8_t *)realloc(store->bitmap, capacity);
    if (bitmap == NULL)
        return false;
    memset(bitmap + store->bitmapLength, 0, capacity - store->bitmapLength);
    store->bitmap = bitmap;
    store->bitmapLength = capacity;
    return true;
}

static inline bool LGMediaStoreBit(const LGMediaStore *store, int64_t block)
{
    size_t byte = (size_t)(block >> 3);
    if (byte >= store->bitmapLength)
        return false;
    return (store->bitmap[byte] & (uint8_t)(1u << (block & 7))) != 0;
}

static void LGMediaStoreSetBits(LGMediaStore *store, int64_t startBlock, int64_t endBlock, bool value)
{
    if (endBlock <= startBlock)
        return;
    if (value && !LGMediaStoreEnsureBitmap(store, endBlock))
    {
        store->failed = true;
        return;
    }
    int64_t limit = (int64_t)store->bitmapLength * 8;
    if (endBlock > limit)
        endBlock = limit;
    int64_t block = startBlock;
    while (block < endBlock && (block & 7) != 0)
    {
        if (value)
            store->bitmap[block >> 3] |= (uint8_t)(1u << (block & 7));
        else
            store->bitmap[block >> 3] &= (uint8_t)~(1u << (block & 7));
        block++;
    }
    if (endBlock - block >= 8)
    {
        int64_t bytes = (endBlock - block) >> 3;
        memset(store->bitmap + (block >> 3), value ? 0xff : 0x00, (size_t)bytes);
        block += bytes << 3;
    }
    while (block < endBlock)
    {
        if (value)
            store->bitmap[block >> 3] |= (uint8_t)(1u << (block & 7));
        else
            store->bitmap[block >> 3] &= (uint8_t)~(1u << (block & 7));
        block++;
    }
}

static int64_t LGMediaStoreScan(const LGMediaStore *store, int64_t block, int64_t endBlock, bool value)
{
    uint8_t skip = value ? 0x00 : 0xff;
    int64_t limit = (int64_t)store->bitmapLength * 8;
    while (block < endBlock)
    {
        if (block >= limit)
            return value ? endBlock : block;
        if ((block & 7) == 0 && endBlock - block >= 8 && store->bitmap[block >> 3] == skip)
        {
            block += 8;
            continue;
        }
        if (LGMediaStoreBit(store, block) == value)
            return block;
        block++;
    }
    return endBlock;
}

static int64_t LGMediaStoreEndBlock(const LGMediaStore *store)
{
    if (store->size > 0)
        return LGMediaStoreBlockCount(store->size);
    return (int64_t)store->bitmapLength * 8;
}

static char *LGMediaStoreSegmentPath(const LGMediaStore *store, int64_t index)
{
    size_t length = strlen(store->path) + 24;
    char *path = (char *)malloc(length);
    if (path != NULL)
        snprintf(path, length, "%s.%lld", store->path, (long long)index);
    return path;
}

static void LGMediaStoreCloseSegment(LGMediaStore *store, int64_t index)
{
    for (int i = 0; i < LGMediaStoreSegmentCacheSize; i++)
    {
        if (store->segments[i].fd >= 0 && store->segments[i].index == index)
        {
            close(store->segments[i].fd);
            store->segments[i].fd = -1;
        }
    }
}

static void LGMediaStoreRemoveSegment(LGMediaStore *store, int64_t index)
{
    LGMediaStoreCloseSegment(store, index);
    char *path = LGMediaStoreSegmentPath(store, index);
    if (path != NULL)
    {
        unlink(path);
        free(path);
    }
}

static int LGMediaStoreSegmentDescriptor(LGMediaStore *store, int64_t index, bool create)
{
    store->segmentStamp++;
    int victim = 0;
    for (int i = 0; i < LGMediaStoreSegmentCacheSize; i++)
    {
        if (store->segments[i].fd >= 0 && store->segments[i].index == index)
        {
            store->segments[i].stamp = store->segmentStamp;
            return store->segments[i].fd;
        }
        if (store->segments[i].fd < 0)
            victim = i;
        else if (store->segments[victim].fd >= 0 && store->segments[i].stamp < store->segments[victim].stamp)
            victim = i;
    }
    char *path = LGMediaStoreSegmentPath(store, index);
    if (path == NULL)
        return -1;
    int fd = open(path, create ? (O_RDWR | O_CREAT) : O_RDWR, S_IRUSR | S_IWUSR);
    free(path);
    if (fd < 0)
        return -1;
    if (store->segments[victim].fd >= 0)
        close(store->segments[victim].fd);
    store->segments[victim].fd = fd;
    store->segments[victim].index = index;
    store->segments[victim].stamp = store->segmentStamp;
    return fd;
}

static bool LGMediaStoreWriteAll(int fd, const uint8_t *bytes, size_t length, int64_t offset)
{
    while (length != 0)
    {
        ssize_t result = pwrite(fd, bytes, length, (off_t)offset);
        if (result < 0)
        {
            if (errno == EINTR)
                continue;
            return false;
        }
        if (result == 0)
            return false;
        bytes += result;
        length -= (size_t)result;
        offset += result;
    }
    return true;
}

static bool LGMediaStoreReadAll(int fd, uint8_t *bytes, size_t length, int64_t offset)
{
    while (length != 0)
    {
        ssize_t result = pread(fd, bytes, length, (off_t)offset);
        if (result < 0)
        {
            if (errno == EINTR)
                continue;
            return false;
        }
        if (result == 0)
            return false;
        bytes += result;
        length -= (size_t)result;
        offset += result;
    }
    return true;
}

static bool LGMediaStoreSegmentIO(LGMediaStore *store, int64_t offset, uint8_t *bytes, size_t length, bool write)
{
    while (length != 0)
    {
        int64_t index = offset / LGMediaStoreSegmentSize;
        int64_t within = offset % LGMediaStoreSegmentSize;
        size_t chunk = (size_t)LGMediaStoreMin((int64_t)length, LGMediaStoreSegmentSize - within);
        int fd = LGMediaStoreSegmentDescriptor(store, index, write);
        if (fd < 0)
            return false;
        bool result = write ? LGMediaStoreWriteAll(fd, bytes, chunk, within) : LGMediaStoreReadAll(fd, bytes, chunk, within);
        if (!result)
            return false;
        offset += (int64_t)chunk;
        bytes += chunk;
        length -= chunk;
    }
    return true;
}

static inline void LGMediaStorePutUInt32(uint8_t *bytes, uint32_t value)
{
    bytes[0] = (uint8_t)value;
    bytes[1] = (uint8_t)(value >> 8);
    bytes[2] = (uint8_t)(value >> 16);
    bytes[3] = (uint8_t)(value >> 24);
}

static inline uint32_t LGMediaStoreGetUInt32(const uint8_t *bytes)
{
    return (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8) | ((uint32_t)bytes[2] << 16) | ((uint32_t)bytes[3] << 24);
}

static inline void LGMediaStorePutInt64(uint8_t *bytes, int64_t value)
{
    LGMediaStorePutUInt32(bytes, (uint32_t)((uint64_t)value & 0xffffffffu));
    LGMediaStorePutUInt32(bytes + 4, (uint32_t)((uint64_t)value >> 32));
}

static inline int64_t LGMediaStoreGetInt64(const uint8_t *bytes)
{
    return (int64_t)((uint64_t)LGMediaStoreGetUInt32(bytes) | ((uint64_t)LGMediaStoreGetUInt32(bytes + 4) << 32));
}

static uint32_t LGMediaStoreChecksum(const uint8_t *bytes, size_t length)
{
    uint32_t hash = 2166136261u;
    for (size_t i = 0; i < length; i++)
    {
        if (i >= 32 && i < 36)
            continue;
        hash ^= bytes[i];
        hash *= 16777619u;
    }
    return hash;
}

static bool LGMediaStoreWriteIndex(LGMediaStore *store)
{
    size_t bitmapBytes = 0;
    if (store->size > 0 && store->farBytes > 0)
        bitmapBytes = (size_t)((LGMediaStoreBlockCount(store->size) + 7) / 8);
    size_t length = LGMediaStoreIndexHeaderLength + store->stateLength + bitmapBytes;
    uint8_t *buffer = (uint8_t *)calloc(1, length);
    if (buffer == NULL)
        return false;
    LGMediaStorePutUInt32(buffer, LGMediaStoreIndexMagic);
    LGMediaStorePutUInt32(buffer + 4, LGMediaStoreBlockSize);
    LGMediaStorePutInt64(buffer + 8, store->size);
    LGMediaStorePutInt64(buffer + 16, store->prefix);
    LGMediaStorePutUInt32(buffer + 24, (uint32_t)store->stateLength);
    LGMediaStorePutUInt32(buffer + 28, (uint32_t)bitmapBytes);
    LGMediaStorePutUInt32(buffer + 36, LGMediaStoreSegmentSize);
    if (store->stateLength != 0)
        memcpy(buffer + LGMediaStoreIndexHeaderLength, store->state, store->stateLength);
    if (bitmapBytes != 0)
    {
        uint8_t *bitmap = buffer + LGMediaStoreIndexHeaderLength + store->stateLength;
        size_t available = bitmapBytes < store->bitmapLength ? bitmapBytes : store->bitmapLength;
        memcpy(bitmap, store->bitmap, available);
        for (size_t i = 0; i < store->partCount; i++)
        {
            int64_t endBlock = LGMediaStoreBlockCount(store->parts[i].offset + (int64_t)store->parts[i].length);
            for (int64_t block = store->parts[i].offset / LGMediaStoreBlockSize; block < endBlock; block++)
            {
                if ((size_t)(block >> 3) < bitmapBytes)
                    bitmap[block >> 3] &= (uint8_t)~(1u << (block & 7));
            }
        }
    }
    LGMediaStorePutUInt32(buffer + 32, LGMediaStoreChecksum(buffer, length));
    int fd = open(store->indexPath, O_WRONLY | O_CREAT, S_IRUSR | S_IWUSR);
    bool result = fd >= 0 && LGMediaStoreWriteAll(fd, buffer, length, 0) && ftruncate(fd, (off_t)length) == 0;
    if (fd >= 0)
        close(fd);
    free(buffer);
    if (result)
        store->indexDirty = false;
    return result;
}

typedef struct {
    bool valid;
    int64_t size;
    int64_t prefix;
    uint8_t *payload;
    size_t bitmapBytes;
} LGMediaStoreIndex;

static LGMediaStoreIndex LGMediaStoreReadIndex(LGMediaStore *store)
{
    LGMediaStoreIndex index;
    memset(&index, 0, sizeof(index));
    int fd = open(store->indexPath, O_RDONLY);
    if (fd < 0)
        return index;
    struct stat value;
    if (fstat(fd, &value) != 0 || value.st_size < LGMediaStoreIndexHeaderLength || value.st_size > 16 * 1024 * 1024)
    {
        close(fd);
        return index;
    }
    size_t length = (size_t)value.st_size;
    uint8_t *buffer = (uint8_t *)malloc(length);
    bool read = buffer != NULL && LGMediaStoreReadAll(fd, buffer, length, 0);
    close(fd);
    if (!read)
    {
        free(buffer);
        return index;
    }
    uint32_t stateLength = LGMediaStoreGetUInt32(buffer + 24);
    uint32_t bitmapBytes = LGMediaStoreGetUInt32(buffer + 28);
    bool valid = LGMediaStoreGetUInt32(buffer) == LGMediaStoreIndexMagic &&
        LGMediaStoreGetUInt32(buffer + 4) == LGMediaStoreBlockSize &&
        LGMediaStoreGetUInt32(buffer + 36) == LGMediaStoreSegmentSize &&
        stateLength == store->stateLength &&
        (size_t)LGMediaStoreIndexHeaderLength + stateLength + bitmapBytes == length &&
        LGMediaStoreGetUInt32(buffer + 32) == LGMediaStoreChecksum(buffer, length);
    if (!valid)
    {
        free(buffer);
        return index;
    }
    index.valid = true;
    index.size = LGMediaStoreGetInt64(buffer + 8);
    index.prefix = LGMediaStoreGetInt64(buffer + 16);
    index.bitmapBytes = bitmapBytes;
    index.payload = buffer;
    return index;
}

static void LGMediaStoreRemoveAllSegments(LGMediaStore *store)
{
    if (!store->hasSegments || store->size <= 0)
        return;
    int64_t count = (store->size + LGMediaStoreSegmentSize - 1) / LGMediaStoreSegmentSize;
    for (int64_t i = 0; i < count; i++)
        LGMediaStoreRemoveSegment(store, i);
    store->hasSegments = false;
}

static void LGMediaStoreCommitPrefix(LGMediaStore *store, uint8_t *bytes, size_t length, bool owned)
{
    uint8_t *buffer = bytes;
    bool allocated = false;
    if (store->transform != NULL)
    {
        if (!owned)
        {
            buffer = (uint8_t *)malloc(length);
            if (buffer == NULL)
            {
                store->failed = true;
                return;
            }
            memcpy(buffer, bytes, length);
            allocated = true;
        }
        store->transform(store->context, store->state, buffer, length);
    }
    int64_t offset = store->prefix;
    if (store->transient)
    {
        int64_t skip = store->origin - offset;
        if (skip < (int64_t)length && store->deliver != NULL)
        {
            size_t start = skip > 0 ? (size_t)skip : 0;
            store->deliver(store->context, buffer + start, length - start);
        }
    }
    else if (!LGMediaStoreWriteAll(store->fd, buffer, length, offset))
    {
        store->failed = true;
    }
    if (allocated)
        free(buffer);
    if (store->failed)
        return;
    LGMediaStoreSetBits(store, offset / LGMediaStoreBlockSize, LGMediaStoreBlockCount(offset + (int64_t)length), true);
    store->prefix = offset + (int64_t)length;
    if (!store->transient && store->stateLength != 0 && !LGMediaStoreWriteIndex(store))
        store->failed = true;
    if (store->hasSegments)
    {
        int64_t first = offset / LGMediaStoreSegmentSize;
        int64_t last = store->prefix / LGMediaStoreSegmentSize;
        for (int64_t index = first; index < last; index++)
            LGMediaStoreRemoveSegment(store, index);
    }
}

static bool LGMediaStoreInsertPart(LGMediaStore *store, int64_t offset, const uint8_t *bytes, size_t length)
{
    if (store->partCount == store->partCapacity)
    {
        size_t capacity = store->partCapacity == 0 ? 8 : store->partCapacity * 2;
        LGMediaStorePart *parts = (LGMediaStorePart *)realloc(store->parts, capacity * sizeof(LGMediaStorePart));
        if (parts == NULL)
            return false;
        store->parts = parts;
        store->partCapacity = capacity;
    }
    uint8_t *copy = (uint8_t *)malloc(length);
    if (copy == NULL)
        return false;
    memcpy(copy, bytes, length);
    size_t position = store->partCount;
    while (position > 0 && store->parts[position - 1].offset > offset)
    {
        store->parts[position] = store->parts[position - 1];
        position--;
    }
    store->parts[position].offset = offset;
    store->parts[position].length = length;
    store->parts[position].bytes = copy;
    store->partCount++;
    store->pendingBytes += (int64_t)length;
    return true;
}

static const LGMediaStorePart *LGMediaStorePartAt(const LGMediaStore *store, int64_t offset)
{
    for (size_t i = 0; i < store->partCount; i++)
    {
        const LGMediaStorePart *part = &store->parts[i];
        if (part->offset > offset)
            break;
        if (offset < part->offset + (int64_t)part->length)
            return part;
    }
    return NULL;
}

static int64_t LGMediaStoreNextPartStart(const LGMediaStore *store, int64_t offset)
{
    for (size_t i = 0; i < store->partCount; i++)
    {
        if (store->parts[i].offset > offset)
            return store->parts[i].offset;
    }
    return INT64_MAX;
}

static int64_t LGMediaStoreSegmentRunEnd(const LGMediaStore *store, int64_t offset)
{
    int64_t endBlock = LGMediaStoreEndBlock(store);
    int64_t segmentEnd = (offset / LGMediaStoreSegmentSize + 1) * LGMediaStoreSegmentSize;
    int64_t end = LGMediaStoreBlockOffset(LGMediaStoreScan(store, offset / LGMediaStoreBlockSize, endBlock, false), endBlock, segmentEnd);
    end = LGMediaStoreMin(end, LGMediaStoreNextPartStart(store, offset));
    if (store->size > 0)
        end = LGMediaStoreMin(end, store->size);
    return end;
}

static void LGMediaStoreDrain(LGMediaStore *store)
{
    while (!store->failed && (store->size <= 0 || store->prefix < store->size))
    {
        if (store->partCount != 0 && store->parts[0].offset == store->prefix)
        {
            LGMediaStorePart part = store->parts[0];
            memmove(store->parts, store->parts + 1, (store->partCount - 1) * sizeof(LGMediaStorePart));
            store->partCount--;
            store->pendingBytes -= (int64_t)part.length;
            LGMediaStoreCommitPrefix(store, part.bytes, part.length, true);
            free(part.bytes);
            continue;
        }
        if (store->transient || !LGMediaStoreBit(store, store->prefix / LGMediaStoreBlockSize))
            break;
        int64_t end = LGMediaStoreSegmentRunEnd(store, store->prefix);
        if (end <= store->prefix)
            break;
        if (store->scratch == NULL)
        {
            store->scratch = (uint8_t *)malloc(LGMediaStoreCopyChunk);
            if (store->scratch == NULL)
            {
                store->failed = true;
                break;
            }
        }
        size_t chunk = (size_t)LGMediaStoreMin(end - store->prefix, LGMediaStoreCopyChunk);
        if (!LGMediaStoreSegmentIO(store, store->prefix, store->scratch, chunk, false))
        {
            int64_t block = store->prefix / LGMediaStoreBlockSize;
            int64_t lost = LGMediaStoreSegmentRunEnd(store, store->prefix);
            int64_t lostBytes = lost - store->prefix;
            LGMediaStoreSetBits(store, block, LGMediaStoreBlockCount(lost), false);
            store->farBytes -= lostBytes;
            store->indexDirty = true;
            break;
        }
        store->farBytes -= (int64_t)chunk;
        store->indexDirty = true;
        LGMediaStoreCommitPrefix(store, store->scratch, chunk, true);
    }
}

static void LGMediaStoreStoreRun(LGMediaStore *store, int64_t offset, const uint8_t *bytes, size_t length)
{
    if (offset == store->prefix)
    {
        LGMediaStoreCommitPrefix(store, (uint8_t *)bytes, length, false);
        return;
    }
    int64_t distance = offset - store->prefix + (int64_t)length;
    bool memory = store->sequential || store->transient || (distance <= store->memoryWindow && store->pendingBytes + (int64_t)length <= store->memoryWindow);
    if (memory)
    {
        if (!LGMediaStoreInsertPart(store, offset, bytes, length))
        {
            store->failed = true;
            return;
        }
    }
    else
    {
        if (!LGMediaStoreSegmentIO(store, offset, (uint8_t *)bytes, length, true))
        {
            store->failed = true;
            return;
        }
        store->hasSegments = true;
        store->farBytes += (int64_t)length;
        store->indexDirty = true;
    }
    LGMediaStoreSetBits(store, offset / LGMediaStoreBlockSize, LGMediaStoreBlockCount(offset + (int64_t)length), true);
}

LGMediaStore *LGMediaStoreCreate(const char *path, const LGMediaStoreConfiguration *configuration)
{
    LGMediaStore *store = (LGMediaStore *)calloc(1, sizeof(LGMediaStore));
    if (store == NULL)
        return NULL;
    pthread_mutex_init(&store->lock, NULL);
    store->fd = -1;
    for (int i = 0; i < LGMediaStoreSegmentCacheSize; i++)
        store->segments[i].fd = -1;
    store->size = configuration->size > 0 ? configuration->size : 0;
    store->origin = configuration->origin > 0 ? configuration->origin : 0;
    store->memoryWindow = configuration->memoryWindow;
    store->sequential = configuration->sequential;
    store->context = configuration->context;
    store->transform = configuration->transform;
    store->deliver = configuration->deliver;
    store->stateLength = configuration->stateLength;
    if (store->stateLength != 0)
    {
        store->state = (uint8_t *)malloc(store->stateLength);
        if (store->state == NULL)
        {
            LGMediaStoreDestroy(store);
            return NULL;
        }
        memcpy(store->state, configuration->initialState, store->stateLength);
    }

    if (path == NULL)
    {
        store->transient = true;
        store->prefix = LGMediaStoreAlignDown(store->origin);
        LGMediaStoreSetBits(store, 0, store->prefix / LGMediaStoreBlockSize, true);
        if (store->failed)
        {
            LGMediaStoreDestroy(store);
            return NULL;
        }
        return store;
    }

    size_t pathLength = strlen(path);
    store->path = strdup(path);
    store->indexPath = (char *)malloc(pathLength + 7);
    if (store->path == NULL || store->indexPath == NULL)
    {
        LGMediaStoreDestroy(store);
        return NULL;
    }
    memcpy(store->indexPath, path, pathLength);
    memcpy(store->indexPath + pathLength, ".index", 7);

    store->fd = open(path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
    struct stat value;
    if (store->fd < 0 || fstat(store->fd, &value) != 0)
    {
        LGMediaStoreDestroy(store);
        return NULL;
    }
    int64_t fileLength = (int64_t)value.st_size;
    bool reset = false;

    LGMediaStoreIndex index = LGMediaStoreReadIndex(store);
    if (index.valid && store->size > 0 && index.size > 0 && index.size != store->size)
    {
        int64_t configured = store->size;
        store->size = index.size;
        store->hasSegments = true;
        LGMediaStoreRemoveAllSegments(store);
        store->size = configured;
        free(index.payload);
        memset(&index, 0, sizeof(index));
        reset = true;
    }
    if (index.valid && store->size == 0 && index.size > 0)
        store->size = index.size;

    int64_t prefix = 0;
    if (!reset && store->stateLength != 0)
    {
        if (index.valid && index.prefix <= fileLength && (store->size == 0 || index.prefix <= store->size))
        {
            prefix = index.prefix;
            memcpy(store->state, index.payload + LGMediaStoreIndexHeaderLength, store->stateLength);
        }
    }
    else if (!reset)
    {
        prefix = fileLength;
        if (store->size > 0 && prefix > store->size)
            prefix = 0;
        if (store->size == 0 || prefix != store->size)
            prefix = LGMediaStoreAlignDown(prefix);
    }
    if (prefix != fileLength && ftruncate(store->fd, (off_t)prefix) != 0)
    {
        free(index.payload);
        LGMediaStoreDestroy(store);
        return NULL;
    }
    store->prefix = prefix;

    int64_t prefixBlocks = LGMediaStoreBlockCount(prefix);
    if (store->size > 0)
    {
        int64_t blockCount = LGMediaStoreBlockCount(store->size);
        if (!LGMediaStoreEnsureBitmap(store, blockCount))
        {
            free(index.payload);
            LGMediaStoreDestroy(store);
            return NULL;
        }
        if (index.valid && store->stateLength == 0 && index.bitmapBytes == (size_t)((blockCount + 7) / 8))
        {
            memcpy(store->bitmap, index.payload + LGMediaStoreIndexHeaderLength + store->stateLength, index.bitmapBytes);
            int64_t mergedBlocks = LGMediaStoreBlockCount(index.prefix);
            if (mergedBlocks > prefixBlocks)
                LGMediaStoreSetBits(store, prefixBlocks, mergedBlocks, false);
            for (int64_t block = prefixBlocks; block < blockCount; block++)
            {
                if (LGMediaStoreBit(store, block))
                    store->farBytes += LGMediaStoreBlockLength(store, block);
            }
            store->hasSegments = store->farBytes > 0;
        }
    }
    LGMediaStoreSetBits(store, 0, prefixBlocks, true);
    if (store->stateLength == 0 && store->farBytes == 0)
        store->indexDirty = true;
    free(index.payload);
    if (store->failed)
    {
        LGMediaStoreDestroy(store);
        return NULL;
    }
    LGMediaStoreDrain(store);
    return store;
}

static void LGMediaStoreSpill(LGMediaStore *store)
{
    if (store->transient || store->sequential || store->failed)
        return;
    for (size_t i = 0; i < store->partCount; i++)
    {
        LGMediaStorePart *part = &store->parts[i];
        if (LGMediaStoreSegmentIO(store, part->offset, part->bytes, part->length, true))
        {
            store->hasSegments = true;
            store->farBytes += (int64_t)part->length;
        }
        else
        {
            LGMediaStoreSetBits(store, part->offset / LGMediaStoreBlockSize, LGMediaStoreBlockCount(part->offset + (int64_t)part->length), false);
        }
        store->indexDirty = true;
        free(part->bytes);
    }
    store->partCount = 0;
    store->pendingBytes = 0;
}

void LGMediaStoreDestroy(LGMediaStore *store)
{
    if (store == NULL)
        return;
    if (!store->transient && !store->finished && store->fd >= 0)
    {
        pthread_mutex_lock(&store->lock);
        LGMediaStoreSpill(store);
        pthread_mutex_unlock(&store->lock);
        LGMediaStoreSynchronize(store);
    }
    if (store->fd >= 0)
        close(store->fd);
    for (int i = 0; i < LGMediaStoreSegmentCacheSize; i++)
    {
        if (store->segments[i].fd >= 0)
            close(store->segments[i].fd);
    }
    for (size_t i = 0; i < store->partCount; i++)
        free(store->parts[i].bytes);
    free(store->parts);
    free(store->bitmap);
    free(store->scratch);
    free(store->state);
    free(store->path);
    free(store->indexPath);
    pthread_mutex_destroy(&store->lock);
    free(store);
}

int64_t LGMediaStoreSize(LGMediaStore *store)
{
    pthread_mutex_lock(&store->lock);
    int64_t size = store->size;
    pthread_mutex_unlock(&store->lock);
    return size;
}

void LGMediaStoreSetSize(LGMediaStore *store, int64_t size)
{
    pthread_mutex_lock(&store->lock);
    if (size > 0 && (store->size == 0 || size < store->size) && size >= store->prefix)
    {
        store->size = size;
        if (!LGMediaStoreEnsureBitmap(store, LGMediaStoreBlockCount(size)))
            store->failed = true;
        LGMediaStoreDrain(store);
    }
    pthread_mutex_unlock(&store->lock);
}

void LGMediaStoreSetMemoryWindow(LGMediaStore *store, int64_t memoryWindow)
{
    pthread_mutex_lock(&store->lock);
    store->memoryWindow = memoryWindow;
    pthread_mutex_unlock(&store->lock);
}

int64_t LGMediaStorePrefix(LGMediaStore *store)
{
    pthread_mutex_lock(&store->lock);
    int64_t prefix = store->prefix;
    pthread_mutex_unlock(&store->lock);
    return prefix;
}

int64_t LGMediaStorePresentBytes(LGMediaStore *store)
{
    pthread_mutex_lock(&store->lock);
    int64_t bytes = store->prefix + store->pendingBytes + store->farBytes;
    pthread_mutex_unlock(&store->lock);
    return bytes;
}

bool LGMediaStoreIsComplete(LGMediaStore *store)
{
    pthread_mutex_lock(&store->lock);
    bool complete = store->size > 0 && store->prefix >= store->size;
    pthread_mutex_unlock(&store->lock);
    return complete;
}

bool LGMediaStoreIsSequential(LGMediaStore *store)
{
    return store->sequential;
}

bool LGMediaStoreWrite(LGMediaStore *store, int64_t offset, const uint8_t *bytes, size_t length)
{
    pthread_mutex_lock(&store->lock);
    if (store->failed || store->finished || offset < 0 || offset % LGMediaStoreBlockSize != 0)
    {
        pthread_mutex_unlock(&store->lock);
        return false;
    }
    int64_t end = offset + (int64_t)length;
    if (store->size > 0)
        end = LGMediaStoreMin(end, store->size);
    if (store->size == 0 || end < store->size)
        end = LGMediaStoreAlignDown(end);
    int64_t cursor = LGMediaStoreMax(offset, store->prefix);
    if (cursor < end && !LGMediaStoreEnsureBitmap(store, LGMediaStoreBlockCount(end)))
        store->failed = true;
    while (!store->failed && cursor < end)
    {
        int64_t block = cursor / LGMediaStoreBlockSize;
        int64_t endBlock = LGMediaStoreBlockCount(end);
        if (LGMediaStoreBit(store, block))
        {
            cursor = LGMediaStoreBlockOffset(LGMediaStoreScan(store, block, endBlock, false), endBlock, end);
            continue;
        }
        int64_t runEnd = LGMediaStoreBlockOffset(LGMediaStoreScan(store, block, endBlock, true), endBlock, end);
        LGMediaStoreStoreRun(store, cursor, bytes + (cursor - offset), (size_t)(runEnd - cursor));
        cursor = runEnd;
    }
    if (!store->failed)
        LGMediaStoreDrain(store);
    bool result = !store->failed;
    pthread_mutex_unlock(&store->lock);
    return result;
}

int64_t LGMediaStoreFirstMissing(LGMediaStore *store, int64_t from, int64_t to)
{
    pthread_mutex_lock(&store->lock);
    int64_t result = -1;
    if (store->size > 0)
        to = LGMediaStoreMin(to, store->size);
    int64_t start = LGMediaStoreMax(LGMediaStoreAlignDown(from), store->prefix);
    if (start < to)
    {
        int64_t endBlock = LGMediaStoreBlockCount(to);
        int64_t block = LGMediaStoreScan(store, start / LGMediaStoreBlockSize, endBlock, false);
        if (block < endBlock && block * LGMediaStoreBlockSize < to)
            result = block * LGMediaStoreBlockSize;
    }
    pthread_mutex_unlock(&store->lock);
    return result;
}

int64_t LGMediaStoreMissingRunEnd(LGMediaStore *store, int64_t from, int64_t to)
{
    pthread_mutex_lock(&store->lock);
    if (store->size > 0)
        to = LGMediaStoreMin(to, store->size);
    int64_t result = from;
    if (from < to)
    {
        int64_t endBlock = LGMediaStoreBlockCount(to);
        result = LGMediaStoreBlockOffset(LGMediaStoreScan(store, from / LGMediaStoreBlockSize, endBlock, true), endBlock, to);
    }
    pthread_mutex_unlock(&store->lock);
    return result;
}

int64_t LGMediaStoreAvailableLength(LGMediaStore *store, int64_t offset)
{
    pthread_mutex_lock(&store->lock);
    int64_t result = 0;
    if (offset >= 0 && (store->size == 0 || offset < store->size))
    {
        int64_t start = LGMediaStoreMax(offset, store->prefix);
        int64_t endBlock = LGMediaStoreEndBlock(store);
        int64_t end = LGMediaStoreBlockOffset(LGMediaStoreScan(store, start / LGMediaStoreBlockSize, endBlock, false), endBlock, INT64_MAX);
        if (store->size > 0)
            end = LGMediaStoreMin(end, store->size);
        else if (store->partCount != 0)
        {
            const LGMediaStorePart *last = &store->parts[store->partCount - 1];
            end = LGMediaStoreMin(end, last->offset + (int64_t)last->length);
        }
        else
            end = LGMediaStoreMin(end, store->prefix);
        result = LGMediaStoreMax(0, end - offset);
    }
    pthread_mutex_unlock(&store->lock);
    return result;
}

ssize_t LGMediaStoreRead(LGMediaStore *store, int64_t offset, uint8_t *buffer, size_t length)
{
    pthread_mutex_lock(&store->lock);
    ssize_t result = 0;
    if (!store->transient && !store->failed && length != 0 && offset >= 0 && (store->size == 0 || offset < store->size))
    {
        if (offset < store->prefix)
        {
            size_t chunk = (size_t)LGMediaStoreMin((int64_t)length, store->prefix - offset);
            if (store->fd >= 0 && LGMediaStoreReadAll(store->fd, buffer, chunk, offset))
                result = (ssize_t)chunk;
            else
                result = -1;
        }
        else if (LGMediaStoreBit(store, offset / LGMediaStoreBlockSize))
        {
            const LGMediaStorePart *part = LGMediaStorePartAt(store, offset);
            if (part != NULL)
            {
                size_t chunk = (size_t)LGMediaStoreMin((int64_t)length, part->offset + (int64_t)part->length - offset);
                memcpy(buffer, part->bytes + (offset - part->offset), chunk);
                result = (ssize_t)chunk;
            }
            else
            {
                int64_t end = LGMediaStoreSegmentRunEnd(store, offset);
                size_t chunk = (size_t)LGMediaStoreMin((int64_t)length, end - offset);
                if (chunk != 0)
                    result = LGMediaStoreSegmentIO(store, offset, buffer, chunk, false) ? (ssize_t)chunk : -1;
            }
        }
    }
    pthread_mutex_unlock(&store->lock);
    return result;
}

bool LGMediaStoreSynchronize(LGMediaStore *store)
{
    pthread_mutex_lock(&store->lock);
    bool result = !store->failed;
    if (!store->transient && !store->finished)
    {
        if (store->farBytes == 0 && store->stateLength == 0)
        {
            if (store->indexDirty)
            {
                unlink(store->indexPath);
                store->indexDirty = false;
            }
        }
        else if (store->indexDirty)
        {
            result = LGMediaStoreWriteIndex(store) && result;
        }
    }
    pthread_mutex_unlock(&store->lock);
    return result;
}

bool LGMediaStoreFinish(LGMediaStore *store, int64_t length)
{
    pthread_mutex_lock(&store->lock);
    bool result = !store->failed && store->size > 0 && store->prefix >= store->size;
    if (result && !store->transient)
    {
        if (length > 0 && length < store->prefix)
            result = ftruncate(store->fd, (off_t)length) == 0;
        close(store->fd);
        store->fd = -1;
        unlink(store->indexPath);
        store->hasSegments = true;
        LGMediaStoreRemoveAllSegments(store);
        for (int i = 0; i < LGMediaStoreSegmentCacheSize; i++)
        {
            if (store->segments[i].fd >= 0)
            {
                close(store->segments[i].fd);
                store->segments[i].fd = -1;
            }
        }
    }
    if (result)
        store->finished = true;
    pthread_mutex_unlock(&store->lock);
    return result;
}
