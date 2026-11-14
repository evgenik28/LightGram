#import "LGDeviceTier.h"

#import <sys/sysctl.h>
#import <pthread.h>

static pthread_once_t LGDeviceTierOnce = PTHREAD_ONCE_INIT;
static LGDeviceTier LGDeviceTierValue = LGDeviceTierLow;
static uint64_t LGDeviceMemoryValue = 0;

static void LGDeviceTierInitialize(void)
{
    uint64_t memory = 0;
    size_t size = sizeof(memory);
    if (sysctlbyname("hw.memsize", &memory, &size, NULL, 0) != 0 || size == 0 || memory == 0)
        memory = [[NSProcessInfo processInfo] physicalMemory];
    LGDeviceMemoryValue = memory;

    uint32_t cores = 1;
    size = sizeof(cores);
    if (sysctlbyname("hw.ncpu", &cores, &size, NULL, 0) != 0 || cores == 0)
        cores = 1;

    if (memory <= 768ULL * 1024ULL * 1024ULL || cores <= 1)
        LGDeviceTierValue = LGDeviceTierLow;
    else if (memory <= 2ULL * 1024ULL * 1024ULL * 1024ULL || cores <= 2)
        LGDeviceTierValue = LGDeviceTierMedium;
    else
        LGDeviceTierValue = LGDeviceTierHigh;
}

LGDeviceTier LGDeviceTierCurrent(void)
{
    pthread_once(&LGDeviceTierOnce, LGDeviceTierInitialize);
    return LGDeviceTierValue;
}

uint64_t LGDevicePhysicalMemory(void)
{
    pthread_once(&LGDeviceTierOnce, LGDeviceTierInitialize);
    return LGDeviceMemoryValue;
}
