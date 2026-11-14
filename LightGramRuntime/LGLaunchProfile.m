#if defined(LIGHTGRAM_LAUNCH_PROFILE)

#import <Foundation/Foundation.h>
#include <libkern/OSAtomic.h>
#include <mach-o/dyld.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <stdio.h>
#include <syslog.h>
#include <unistd.h>

#define LG_LAUNCH_PROFILE_FUNCTION __attribute__((no_instrument_function))

enum
{
    LGLaunchProfileTableSize = 1 << 17,
    LGLaunchProfileListCapacity = 1 << 16,
    LGLaunchProfileProbeLimit = 64,
    LGLaunchProfileAddressesPerLine = 32
};

static const uint64_t LGLaunchProfileDurationSeconds = 240;

static uintptr_t volatile LGLaunchProfileTable[LGLaunchProfileTableSize];
static uintptr_t LGLaunchProfileList[LGLaunchProfileListCapacity];
static volatile int32_t LGLaunchProfileCount = 0;
static volatile int32_t LGLaunchProfileActive = 1;

void __cyg_profile_func_enter(void *function, void *site) LG_LAUNCH_PROFILE_FUNCTION;
void __cyg_profile_func_exit(void *function, void *site) LG_LAUNCH_PROFILE_FUNCTION;

void __cyg_profile_func_enter(void *function, void *site)
{
    (void)site;
    if (LGLaunchProfileActive == 0 || function == NULL)
        return;
    uintptr_t key = (uintptr_t)function;
    uint32_t hash = (uint32_t)(key >> 1) * 2654435761u;
    for (uint32_t probe = 0; probe < LGLaunchProfileProbeLimit; probe++)
    {
        uintptr_t volatile *slot = &LGLaunchProfileTable[(hash + probe) & (LGLaunchProfileTableSize - 1)];
        uintptr_t current = *slot;
        if (current == key)
            return;
        if (current != 0)
            continue;
        if (!OSAtomicCompareAndSwapPtrBarrier(NULL, (void *)key, (void *volatile *)slot))
        {
            if (*slot == key)
                return;
            continue;
        }
        int32_t position = OSAtomicIncrement32Barrier(&LGLaunchProfileCount) - 1;
        if (position < LGLaunchProfileListCapacity)
            LGLaunchProfileList[position] = key;
        else
            LGLaunchProfileActive = 0;
        return;
    }
}

void __cyg_profile_func_exit(void *function, void *site)
{
    (void)function;
    (void)site;
}

static void LGLaunchProfileWrite(uintptr_t slide, int32_t count) LG_LAUNCH_PROFILE_FUNCTION;
static void LGLaunchProfileWrite(uintptr_t slide, int32_t count)
{
    @autoreleasepool
    {
        NSArray *directories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *path = directories.count == 0 ? nil : [[directories objectAtIndex:0] stringByAppendingPathComponent:@"launch-order.txt"];
        FILE *file = path == nil ? NULL : fopen([path fileSystemRepresentation], "w");
        char line[LGLaunchProfileAddressesPerLine * 10 + 64];
        int32_t chunk = 0;
        for (int32_t start = 0; start < count; start += LGLaunchProfileAddressesPerLine)
        {
            int length = snprintf(line, sizeof(line), "LAUNCHORDER chunk=%d", (int)chunk++);
            int32_t end = MIN(count, start + LGLaunchProfileAddressesPerLine);
            for (int32_t index = start; index < end; index++)
            {
                uintptr_t address = LGLaunchProfileList[index] - slide;
                length += snprintf(line + length, sizeof(line) - (size_t)length, " %lx", (unsigned long)address);
                if (file != NULL)
                    fprintf(file, "%lx\n", (unsigned long)address);
            }
            syslog(LOG_WARNING, "%s", line);
            usleep(2000);
        }
        if (file != NULL)
            fclose(file);
        syslog(LOG_WARNING, "LAUNCHORDER end count=%d slide=%lx", (int)count, (unsigned long)slide);
    }
}

static void *LGLaunchProfileThreadMain(void *context) LG_LAUNCH_PROFILE_FUNCTION;
static void *LGLaunchProfileThreadMain(void *context)
{
    (void)context;
    sleep((unsigned int)LGLaunchProfileDurationSeconds);
    LGLaunchProfileActive = 0;
    OSMemoryBarrier();
    int32_t count = MIN(LGLaunchProfileCount, (int32_t)LGLaunchProfileListCapacity);
    LGLaunchProfileWrite((uintptr_t)_dyld_get_image_vmaddr_slide(0), count);
    return NULL;
}

__attribute__((constructor, no_instrument_function)) static void LGLaunchProfileStart(void)
{
    pthread_t thread;
    if (pthread_create(&thread, NULL, LGLaunchProfileThreadMain, NULL) == 0)
        pthread_detach(thread);
}

#endif
