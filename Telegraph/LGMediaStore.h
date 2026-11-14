#ifndef LGMediaStore_h
#define LGMediaStore_h

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LGMediaStoreBlockSize 4096
#define LGMediaStoreSegmentSize (1024 * 1024)

typedef struct LGMediaStore LGMediaStore;

typedef void (*LGMediaStoreTransform)(void *context, void *state, uint8_t *bytes, size_t length);
typedef void (*LGMediaStoreDeliver)(void *context, const uint8_t *bytes, size_t length);

typedef struct {
    int64_t size;
    int64_t origin;
    int64_t memoryWindow;
    bool sequential;
    size_t stateLength;
    const void *initialState;
    void *context;
    LGMediaStoreTransform transform;
    LGMediaStoreDeliver deliver;
} LGMediaStoreConfiguration;

LGMediaStore *LGMediaStoreCreate(const char *path, const LGMediaStoreConfiguration *configuration);
void LGMediaStoreDestroy(LGMediaStore *store);

int64_t LGMediaStoreSize(LGMediaStore *store);
void LGMediaStoreSetSize(LGMediaStore *store, int64_t size);
void LGMediaStoreSetMemoryWindow(LGMediaStore *store, int64_t memoryWindow);
int64_t LGMediaStorePrefix(LGMediaStore *store);
int64_t LGMediaStorePresentBytes(LGMediaStore *store);
bool LGMediaStoreIsComplete(LGMediaStore *store);
bool LGMediaStoreIsSequential(LGMediaStore *store);

bool LGMediaStoreWrite(LGMediaStore *store, int64_t offset, const uint8_t *bytes, size_t length);

int64_t LGMediaStoreFirstMissing(LGMediaStore *store, int64_t from, int64_t to);
int64_t LGMediaStoreMissingRunEnd(LGMediaStore *store, int64_t from, int64_t to);
int64_t LGMediaStoreAvailableLength(LGMediaStore *store, int64_t offset);
ssize_t LGMediaStoreRead(LGMediaStore *store, int64_t offset, uint8_t *buffer, size_t length);

bool LGMediaStoreSynchronize(LGMediaStore *store);
bool LGMediaStoreFinish(LGMediaStore *store, int64_t length);

#ifdef __cplusplus
}
#endif

#endif
