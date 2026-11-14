#import <Foundation/Foundation.h>

typedef struct
{
    size_t inUse;
    size_t reserved;
    uint64_t ticks;
} LGMemoryGrowthSample;

FOUNDATION_EXPORT void LGCPUProfilerStart(void);
FOUNDATION_EXPORT void LGCPUProfilerRegisterMemoryCounter(NSString *name, uint64_t (^bytes)(void));
FOUNDATION_EXPORT LGMemoryGrowthSample LGMemoryGrowthBegin(void);
FOUNDATION_EXPORT void LGMemoryGrowthEnd(LGMemoryGrowthSample sample, const char *queue, const char *file, int line);
