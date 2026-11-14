#import "LGUpdateArchive.h"

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <unistd.h>
#include <zlib.h>

enum {
    LGUpdateArchiveEndRecordSize = 22,
    LGUpdateArchiveCentralRecordSize = 46,
    LGUpdateArchiveLocalRecordSize = 30,
    LGUpdateArchiveMaximumComment = 65535,
    LGUpdateArchiveMaximumEntries = 20000,
    LGUpdateArchiveMaximumCentralDirectory = 8 * 1024 * 1024,
    LGUpdateArchiveChunkSize = 64 * 1024
};

static const uint32_t LGUpdateArchiveEndSignature = 0x06054b50;
static const uint32_t LGUpdateArchiveCentralSignature = 0x02014b50;
static const uint32_t LGUpdateArchiveLocalSignature = 0x04034b50;
static const uint64_t LGUpdateArchiveMaximumEntrySize = 512ULL * 1024ULL * 1024ULL;
static const uint64_t LGUpdateArchiveMaximumTotalSize = 1024ULL * 1024ULL * 1024ULL;
static const uint64_t LGUpdateArchiveSpaceReserve = 16ULL * 1024ULL * 1024ULL;

typedef struct {
    uint16_t method;
    uint32_t crc;
    uint64_t compressedSize;
    uint64_t uncompressedSize;
    uint64_t localHeaderOffset;
    bool directory;
    bool executable;
} LGUpdateArchiveEntryInfo;

@interface LGUpdateArchiveEntry : NSObject
{
@public
    LGUpdateArchiveEntryInfo _info;
}

@property (nonatomic, strong) NSString *relativePath;

@end

@implementation LGUpdateArchiveEntry

@end

static uint16_t LGUpdateArchiveRead16(const uint8_t *bytes)
{
    return (uint16_t)(bytes[0] | ((uint16_t)bytes[1] << 8));
}

static uint32_t LGUpdateArchiveRead32(const uint8_t *bytes)
{
    return (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8) | ((uint32_t)bytes[2] << 16) | ((uint32_t)bytes[3] << 24);
}

static bool LGUpdateArchiveReadAt(int fd, void *buffer, size_t length, uint64_t offset)
{
    uint8_t *cursor = buffer;
    while (length > 0)
    {
        ssize_t result = pread(fd, cursor, length, (off_t)offset);
        if (result < 0 && errno == EINTR)
            continue;
        if (result <= 0)
            return false;
        cursor += result;
        length -= (size_t)result;
        offset += (uint64_t)result;
    }
    return true;
}

static bool LGUpdateArchiveWriteAll(int fd, const uint8_t *bytes, size_t length)
{
    while (length > 0)
    {
        ssize_t result = write(fd, bytes, length);
        if (result < 0 && errno == EINTR)
            continue;
        if (result <= 0)
            return false;
        bytes += result;
        length -= (size_t)result;
    }
    return true;
}

static LGUpdateArchiveStatus LGUpdateArchiveStatusForErrno(int error)
{
    if (error == EACCES || error == EPERM || error == EROFS)
        return LGUpdateArchiveStatusNotWritable;
    if (error == ENOSPC || error == EDQUOT)
        return LGUpdateArchiveStatusNoSpace;
    return LGUpdateArchiveStatusIO;
}

static LGUpdateArchiveStatus LGUpdateArchiveCreateDirectories(NSString *root, NSString *relativePath)
{
    NSString *current = root;
    for (NSString *component in [relativePath componentsSeparatedByString:@"/"])
    {
        struct stat info;
        if (component.length == 0)
            continue;
        current = [current stringByAppendingPathComponent:component];
        const char *representation = [current fileSystemRepresentation];
        if (lstat(representation, &info) == 0)
        {
            if (S_ISDIR(info.st_mode))
                continue;
            if (unlink(representation) != 0)
                return LGUpdateArchiveStatusForErrno(errno);
        }
        if (mkdir(representation, 0755) != 0 && errno != EEXIST)
            return LGUpdateArchiveStatusForErrno(errno);
    }
    return LGUpdateArchiveStatusOK;
}

static bool LGUpdateArchiveComponentIsSafe(NSString *component)
{
    if (component.length == 0 || [component isEqualToString:@"."] || [component isEqualToString:@".."])
        return false;
    return [component rangeOfString:@"\\"].location == NSNotFound;
}

static NSString *LGUpdateArchiveSafeRelativePath(NSString *path)
{
    if (path.length == 0 || [path hasPrefix:@"/"])
        return nil;
    NSArray *components = [path componentsSeparatedByString:@"/"];
    for (NSString *component in components)
    {
        if (!LGUpdateArchiveComponentIsSafe(component))
            return nil;
    }
    return [components componentsJoinedByString:@"/"];
}

@implementation LGUpdateArchive

+ (void)removeItemAtPath:(NSString *)path
{
    if (path.length == 0)
        return;
    [[[NSFileManager alloc] init] removeItemAtPath:path error:NULL];
}

+ (LGUpdateArchiveStatus)prepareDirectoryAtPath:(NSString *)path
{
    struct stat info;
    if (lstat([path fileSystemRepresentation], &info) == 0)
        [self removeItemAtPath:path];
    if (mkdir([path fileSystemRepresentation], 0755) != 0)
        return LGUpdateArchiveStatusForErrno(errno);
    return LGUpdateArchiveStatusOK;
}

+ (LGUpdateArchiveStatus)readEntries:(NSMutableArray *)entries fromDescriptor:(int)fd archiveSize:(uint64_t)archiveSize centralDirectoryOffset:(uint64_t *)centralDirectoryOffset
{
    size_t tailLength = (size_t)MIN(archiveSize, (uint64_t)(LGUpdateArchiveEndRecordSize + LGUpdateArchiveMaximumComment));
    uint64_t tailOffset = archiveSize - tailLength;
    NSMutableData *tail = [[NSMutableData alloc] initWithLength:tailLength];
    const uint8_t *end = NULL;
    uint64_t endOffset = 0;

    if (tailLength < LGUpdateArchiveEndRecordSize || !LGUpdateArchiveReadAt(fd, tail.mutableBytes, tailLength, tailOffset))
        return LGUpdateArchiveStatusFormat;

    const uint8_t *tailBytes = tail.bytes;
    for (size_t index = tailLength - LGUpdateArchiveEndRecordSize + 1; index-- > 0;)
    {
        if (LGUpdateArchiveRead32(tailBytes + index) != LGUpdateArchiveEndSignature)
            continue;
        if (index + LGUpdateArchiveEndRecordSize + LGUpdateArchiveRead16(tailBytes + index + 20) != tailLength)
            continue;
        end = tailBytes + index;
        endOffset = tailOffset + index;
        break;
    }
    if (end == NULL)
        return LGUpdateArchiveStatusFormat;

    uint16_t diskNumber = LGUpdateArchiveRead16(end + 4);
    uint16_t directoryDisk = LGUpdateArchiveRead16(end + 6);
    uint16_t entriesOnDisk = LGUpdateArchiveRead16(end + 8);
    uint16_t entryCount = LGUpdateArchiveRead16(end + 10);
    uint32_t directorySize = LGUpdateArchiveRead32(end + 12);
    uint32_t directoryOffset = LGUpdateArchiveRead32(end + 16);

    if (entryCount == 0xffff || directorySize == 0xffffffff || directoryOffset == 0xffffffff)
        return LGUpdateArchiveStatusUnsupported;
    if (diskNumber != 0 || directoryDisk != 0 || entriesOnDisk != entryCount)
        return LGUpdateArchiveStatusUnsupported;
    if (entryCount > LGUpdateArchiveMaximumEntries || directorySize > LGUpdateArchiveMaximumCentralDirectory)
        return LGUpdateArchiveStatusLimit;
    if ((uint64_t)directoryOffset + directorySize > endOffset)
        return LGUpdateArchiveStatusFormat;

    NSMutableData *directory = [[NSMutableData alloc] initWithLength:directorySize];
    if (directorySize != 0 && !LGUpdateArchiveReadAt(fd, directory.mutableBytes, directorySize, directoryOffset))
        return LGUpdateArchiveStatusIO;

    const uint8_t *cursor = directory.bytes;
    const uint8_t *limit = cursor + directorySize;
    NSString *applicationName = nil;
    NSMutableSet *knownPaths = [[NSMutableSet alloc] init];
    uint64_t totalSize = 0;

    for (uint16_t index = 0; index < entryCount; index++)
    {
        if ((size_t)(limit - cursor) < LGUpdateArchiveCentralRecordSize || LGUpdateArchiveRead32(cursor) != LGUpdateArchiveCentralSignature)
            return LGUpdateArchiveStatusFormat;

        uint16_t madeBy = LGUpdateArchiveRead16(cursor + 4);
        uint16_t flags = LGUpdateArchiveRead16(cursor + 8);
        uint16_t method = LGUpdateArchiveRead16(cursor + 10);
        uint32_t crc = LGUpdateArchiveRead32(cursor + 16);
        uint32_t compressedSize = LGUpdateArchiveRead32(cursor + 20);
        uint32_t uncompressedSize = LGUpdateArchiveRead32(cursor + 24);
        uint16_t nameLength = LGUpdateArchiveRead16(cursor + 28);
        uint16_t extraLength = LGUpdateArchiveRead16(cursor + 30);
        uint16_t commentLength = LGUpdateArchiveRead16(cursor + 32);
        uint32_t externalAttributes = LGUpdateArchiveRead32(cursor + 38);
        uint32_t localHeaderOffset = LGUpdateArchiveRead32(cursor + 42);
        size_t recordLength = LGUpdateArchiveCentralRecordSize + (size_t)nameLength + extraLength + commentLength;

        if ((size_t)(limit - cursor) < recordLength)
            return LGUpdateArchiveStatusFormat;
        if (compressedSize == 0xffffffff || uncompressedSize == 0xffffffff || localHeaderOffset == 0xffffffff)
            return LGUpdateArchiveStatusUnsupported;
        if ((flags & 0x0041) != 0 || (method != 0 && method != 8))
            return LGUpdateArchiveStatusUnsupported;
        if (memchr(cursor + LGUpdateArchiveCentralRecordSize, 0, nameLength) != NULL)
            return LGUpdateArchiveStatusUnsafeEntry;

        NSString *name = [[NSString alloc] initWithBytes:cursor + LGUpdateArchiveCentralRecordSize length:nameLength encoding:NSUTF8StringEncoding];
        cursor += recordLength;
        if (name == nil)
            return LGUpdateArchiveStatusUnsafeEntry;
        if (![name hasPrefix:@"Payload/"])
            continue;

        NSString *payloadPath = [name substringFromIndex:@"Payload/".length];
        bool directoryEntry = [payloadPath hasSuffix:@"/"];
        if (directoryEntry)
            payloadPath = [payloadPath substringToIndex:payloadPath.length - 1];
        if (payloadPath.length == 0)
            continue;

        NSRange separator = [payloadPath rangeOfString:@"/"];
        NSString *bundleName = separator.location == NSNotFound ? payloadPath : [payloadPath substringToIndex:separator.location];
        if (!LGUpdateArchiveComponentIsSafe(bundleName) || ![[bundleName pathExtension] isEqualToString:@"app"])
            return LGUpdateArchiveStatusUnsafeEntry;
        if (applicationName == nil)
            applicationName = bundleName;
        else if (![applicationName isEqualToString:bundleName])
            return LGUpdateArchiveStatusUnsafeEntry;
        if (separator.location == NSNotFound)
            continue;

        NSString *relativePath = LGUpdateArchiveSafeRelativePath([payloadPath substringFromIndex:separator.location + 1]);
        if (relativePath == nil)
            return LGUpdateArchiveStatusUnsafeEntry;
        if ([knownPaths containsObject:relativePath])
            return LGUpdateArchiveStatusFormat;
        [knownPaths addObject:relativePath];

        uint32_t mode = (madeBy >> 8) == 3 ? (externalAttributes >> 16) : 0;
        if (S_ISLNK(mode))
            return LGUpdateArchiveStatusUnsupported;
        if (S_ISDIR(mode))
            directoryEntry = true;
        if (!directoryEntry && (method == 0 && compressedSize != uncompressedSize))
            return LGUpdateArchiveStatusFormat;
        if (uncompressedSize > LGUpdateArchiveMaximumEntrySize)
            return LGUpdateArchiveStatusLimit;
        totalSize += uncompressedSize;
        if (totalSize > LGUpdateArchiveMaximumTotalSize)
            return LGUpdateArchiveStatusLimit;

        LGUpdateArchiveEntry *entry = [[LGUpdateArchiveEntry alloc] init];
        entry.relativePath = relativePath;
        entry->_info.method = method;
        entry->_info.crc = crc;
        entry->_info.compressedSize = compressedSize;
        entry->_info.uncompressedSize = uncompressedSize;
        entry->_info.localHeaderOffset = localHeaderOffset;
        entry->_info.directory = directoryEntry;
        entry->_info.executable = (mode & 0111) != 0;
        [entries addObject:entry];
    }

    if (applicationName == nil || entries.count == 0)
        return LGUpdateArchiveStatusFormat;

    *centralDirectoryOffset = directoryOffset;
    return LGUpdateArchiveStatusOK;
}

+ (LGUpdateArchiveStatus)extractEntry:(LGUpdateArchiveEntry *)entry fromDescriptor:(int)fd centralDirectoryOffset:(uint64_t)centralDirectoryOffset intoDirectory:(NSString *)directory isCancelled:(bool (^)(void))isCancelled progress:(void (^)(uint64_t written))progress
{
    uint8_t localHeader[LGUpdateArchiveLocalRecordSize];
    const LGUpdateArchiveEntryInfo *info = &entry->_info;

    if (!LGUpdateArchiveReadAt(fd, localHeader, sizeof(localHeader), info->localHeaderOffset) || LGUpdateArchiveRead32(localHeader) != LGUpdateArchiveLocalSignature)
        return LGUpdateArchiveStatusFormat;

    uint64_t dataOffset = info->localHeaderOffset + LGUpdateArchiveLocalRecordSize + LGUpdateArchiveRead16(localHeader + 26) + LGUpdateArchiveRead16(localHeader + 28);
    if (dataOffset + info->compressedSize > centralDirectoryOffset)
        return LGUpdateArchiveStatusFormat;

    LGUpdateArchiveStatus status = LGUpdateArchiveCreateDirectories(directory, [entry.relativePath stringByDeletingLastPathComponent]);
    if (status != LGUpdateArchiveStatusOK)
        return status;

    NSString *path = [directory stringByAppendingPathComponent:entry.relativePath];
    int output = open([path fileSystemRepresentation], O_WRONLY | O_CREAT | O_EXCL, info->executable ? 0755 : 0644);
    if (output < 0)
        return LGUpdateArchiveStatusForErrno(errno);

    NSMutableData *inputBuffer = [[NSMutableData alloc] initWithLength:LGUpdateArchiveChunkSize];
    NSMutableData *outputBuffer = [[NSMutableData alloc] initWithLength:LGUpdateArchiveChunkSize];
    uint8_t *input = inputBuffer.mutableBytes;
    uint8_t *outputBytes = outputBuffer.mutableBytes;
    uint64_t remaining = info->compressedSize;
    uint64_t produced = 0;
    uLong crc = crc32(0L, Z_NULL, 0);
    z_stream stream;
    bool inflating = info->method == 8;
    bool streamEnded = !inflating || (info->compressedSize == 0 && info->uncompressedSize == 0);

    memset(&stream, 0, sizeof(stream));
    if (inflating && inflateInit2(&stream, -MAX_WBITS) != Z_OK)
    {
        close(output);
        return LGUpdateArchiveStatusIO;
    }

    status = LGUpdateArchiveStatusOK;
    while (status == LGUpdateArchiveStatusOK && remaining > 0)
    {
        if (isCancelled != nil && isCancelled())
        {
            status = LGUpdateArchiveStatusCancelled;
            break;
        }

        size_t chunk = (size_t)MIN(remaining, (uint64_t)LGUpdateArchiveChunkSize);
        if (!LGUpdateArchiveReadAt(fd, input, chunk, dataOffset + (info->compressedSize - remaining)))
        {
            status = LGUpdateArchiveStatusIO;
            break;
        }
        remaining -= chunk;

        if (!inflating)
        {
            crc = crc32(crc, input, (uInt)chunk);
            produced += chunk;
            if (!LGUpdateArchiveWriteAll(output, input, chunk))
                status = LGUpdateArchiveStatusForErrno(errno);
            else if (progress != nil)
                progress(chunk);
            continue;
        }

        stream.next_in = input;
        stream.avail_in = (uInt)chunk;
        while (status == LGUpdateArchiveStatusOK && stream.avail_in > 0 && !streamEnded)
        {
            stream.next_out = outputBytes;
            stream.avail_out = LGUpdateArchiveChunkSize;
            int result = inflate(&stream, Z_NO_FLUSH);
            if (result != Z_OK && result != Z_STREAM_END)
            {
                status = LGUpdateArchiveStatusFormat;
                break;
            }
            size_t length = LGUpdateArchiveChunkSize - stream.avail_out;
            produced += length;
            if (produced > info->uncompressedSize)
            {
                status = LGUpdateArchiveStatusFormat;
                break;
            }
            crc = crc32(crc, outputBytes, (uInt)length);
            if (!LGUpdateArchiveWriteAll(output, outputBytes, length))
            {
                status = LGUpdateArchiveStatusForErrno(errno);
                break;
            }
            if (progress != nil && length != 0)
                progress(length);
            if (result == Z_STREAM_END)
                streamEnded = true;
        }
    }

    if (inflating)
        inflateEnd(&stream);
    if (close(output) != 0 && status == LGUpdateArchiveStatusOK)
        status = LGUpdateArchiveStatusForErrno(errno);

    if (status == LGUpdateArchiveStatusOK && (!streamEnded || produced != info->uncompressedSize))
        status = LGUpdateArchiveStatusFormat;
    if (status == LGUpdateArchiveStatusOK && (uint32_t)crc != info->crc)
        status = LGUpdateArchiveStatusChecksum;
    return status;
}

+ (LGUpdateArchiveStatus)extractApplicationFromArchiveAtPath:(NSString *)archivePath toDirectory:(NSString *)directory isCancelled:(bool (^)(void))isCancelled progress:(void (^)(uint64_t, uint64_t))progress
{
    int fd = open([archivePath fileSystemRepresentation], O_RDONLY);
    if (fd < 0)
        return LGUpdateArchiveStatusIO;

    struct stat archiveInfo;
    if (fstat(fd, &archiveInfo) != 0 || !S_ISREG(archiveInfo.st_mode))
    {
        close(fd);
        return LGUpdateArchiveStatusIO;
    }

    NSMutableArray *entries = [[NSMutableArray alloc] init];
    uint64_t centralDirectoryOffset = 0;
    LGUpdateArchiveStatus status = [self readEntries:entries fromDescriptor:fd archiveSize:(uint64_t)archiveInfo.st_size centralDirectoryOffset:&centralDirectoryOffset];

    uint64_t total = 0;
    for (LGUpdateArchiveEntry *entry in entries)
        total += entry->_info.uncompressedSize;

    if (status == LGUpdateArchiveStatusOK)
    {
        struct statfs volume;
        if (statfs([directory fileSystemRepresentation], &volume) == 0 && (uint64_t)volume.f_bavail * (uint64_t)volume.f_bsize < total + LGUpdateArchiveSpaceReserve)
            status = LGUpdateArchiveStatusNoSpace;
    }

    __block uint64_t completed = 0;
    void (^written)(uint64_t) = ^(uint64_t length)
    {
        completed += length;
        if (progress != nil)
            progress(completed, total);
    };

    for (LGUpdateArchiveEntry *entry in entries)
    {
        if (status != LGUpdateArchiveStatusOK)
            break;
        if (entry->_info.directory)
            status = LGUpdateArchiveCreateDirectories(directory, entry.relativePath);
        else
            status = [self extractEntry:entry fromDescriptor:fd centralDirectoryOffset:centralDirectoryOffset intoDirectory:directory isCancelled:isCancelled progress:written];
    }

    close(fd);
    if (status == LGUpdateArchiveStatusOK)
        sync();
    return status;
}

+ (void)collectFilesAtPath:(NSString *)root relativePath:(NSString *)relativePath skipping:(NSString *)skippedName files:(NSMutableArray *)files directories:(NSMutableArray *)directories
{
    NSString *path = relativePath.length == 0 ? root : [root stringByAppendingPathComponent:relativePath];
    NSArray *names = [[[NSFileManager alloc] init] contentsOfDirectoryAtPath:path error:NULL];
    for (NSString *name in names)
    {
        if (relativePath.length == 0 && skippedName != nil && [name isEqualToString:skippedName])
            continue;
        NSString *childRelativePath = relativePath.length == 0 ? name : [relativePath stringByAppendingPathComponent:name];
        struct stat info;
        if (lstat([[root stringByAppendingPathComponent:childRelativePath] fileSystemRepresentation], &info) != 0)
            continue;
        if (S_ISDIR(info.st_mode))
        {
            [directories addObject:childRelativePath];
            [self collectFilesAtPath:root relativePath:childRelativePath skipping:skippedName files:files directories:directories];
        }
        else
            [files addObject:childRelativePath];
    }
}

+ (LGUpdateArchiveStatus)replaceBundleAtPath:(NSString *)bundlePath withStagedBundleAtPath:(NSString *)stagedPath executableName:(NSString *)executableName progress:(void (^)(uint64_t, uint64_t))progress
{
    NSString *skippedName = [[stagedPath stringByDeletingLastPathComponent] isEqualToString:bundlePath] ? [stagedPath lastPathComponent] : nil;
    NSMutableArray *stagedFiles = [[NSMutableArray alloc] init];
    NSMutableArray *stagedDirectories = [[NSMutableArray alloc] init];
    [self collectFilesAtPath:stagedPath relativePath:@"" skipping:nil files:stagedFiles directories:stagedDirectories];
    if (![stagedFiles containsObject:executableName] || ![stagedFiles containsObject:@"Info.plist"])
        return LGUpdateArchiveStatusFormat;

    [stagedFiles removeObject:@"Info.plist"];
    [stagedFiles removeObject:executableName];
    [stagedFiles addObject:@"Info.plist"];
    [stagedFiles addObject:executableName];

    uint64_t total = stagedFiles.count;
    uint64_t completed = 0;
    for (NSString *relativePath in stagedFiles)
    {
        NSString *destination = [bundlePath stringByAppendingPathComponent:relativePath];
        LGUpdateArchiveStatus status = LGUpdateArchiveCreateDirectories(bundlePath, [relativePath stringByDeletingLastPathComponent]);
        if (status != LGUpdateArchiveStatusOK)
            return status;

        struct stat info;
        if (lstat([destination fileSystemRepresentation], &info) == 0 && S_ISDIR(info.st_mode))
            [self removeItemAtPath:destination];

        if (rename([[stagedPath stringByAppendingPathComponent:relativePath] fileSystemRepresentation], [destination fileSystemRepresentation]) != 0)
            return LGUpdateArchiveStatusForErrno(errno);

        completed++;
        if (progress != nil)
            progress(completed, total);
    }

    NSSet *newFiles = [[NSSet alloc] initWithArray:stagedFiles];
    NSSet *newDirectories = [[NSSet alloc] initWithArray:stagedDirectories];
    NSMutableArray *currentFiles = [[NSMutableArray alloc] init];
    NSMutableArray *currentDirectories = [[NSMutableArray alloc] init];
    [self collectFilesAtPath:bundlePath relativePath:@"" skipping:skippedName files:currentFiles directories:currentDirectories];

    for (NSString *relativePath in currentFiles)
    {
        if (![newFiles containsObject:relativePath])
            unlink([[bundlePath stringByAppendingPathComponent:relativePath] fileSystemRepresentation]);
    }
    for (NSString *relativePath in [currentDirectories reverseObjectEnumerator])
    {
        if (![newDirectories containsObject:relativePath])
            [self removeItemAtPath:[bundlePath stringByAppendingPathComponent:relativePath]];
    }

    [self removeItemAtPath:stagedPath];
    sync();
    return LGUpdateArchiveStatusOK;
}

@end
