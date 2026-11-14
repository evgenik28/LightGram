#import "LGCPUProfiler.h"


#import "../LightGramPlatform/LGPlatformDispatch.h"
#include <dlfcn.h>
#include <pthread.h>
#include <sched.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <mach/thread_policy.h>
#include <libkern/OSAtomic.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <malloc/malloc.h>

enum {
    LGCPUProfilerMaximumThreads = 64,
    LGCPUProfilerMaximumFrames = 32,
    LGCPUProfilerFrameSlots = 64,
    LGCPUProfilerReportedThreads = 4,
    LGCPUProfilerReportedFrames = 6,
    LGCPUProfilerReportedImages = 5,
    LGCPUProfilerMainInclusiveSlots = 512,
    LGCPUProfilerMainReportedFrames = 24
};

static const useconds_t LGCPUProfilerSampleInterval = 100000;
static const double LGCPUProfilerWindow = 5.0;
static const double LGCPUProfilerReportLoad = 0.3;

typedef int (*LGCPUProfilerGetNameFunction)(pthread_t, char *, size_t);
typedef pthread_t (*LGCPUProfilerFromMachThreadFunction)(mach_port_t);

typedef struct {
    uintptr_t address;
    uint32_t count;
} LGCPUProfilerFrameSlot;

typedef struct {
    thread_act_t port;
    bool used;
    bool present;
    uintptr_t stackLow;
    uintptr_t stackHigh;
    double baseline;
    double current;
    uint32_t samples;
    uint32_t overflow;
    LGCPUProfilerFrameSlot codeFrames[LGCPUProfilerFrameSlots];
    LGCPUProfilerFrameSlot callerFrames[LGCPUProfilerFrameSlots];
    LGCPUProfilerFrameSlot leafFrames[LGCPUProfilerFrameSlots];
} LGCPUProfilerThread;

static LGCPUProfilerThread LGCPUProfilerThreads[LGCPUProfilerMaximumThreads];
static thread_act_t LGCPUProfilerMainThread = MACH_PORT_NULL;
static thread_act_t LGCPUProfilerSelfThread = MACH_PORT_NULL;
static uintptr_t LGCPUProfilerTextStart = 0;
static uintptr_t LGCPUProfilerTextEnd = 0;
static uintptr_t LGCPUProfilerSlide = 0;
static LGCPUProfilerGetNameFunction LGCPUProfilerGetName = NULL;
static LGCPUProfilerFromMachThreadFunction LGCPUProfilerFromMachThread = NULL;
static double LGCPUProfilerTickSeconds = 0.0;
static pthread_mutex_t LGCPUProfilerMemoryCountersLock = PTHREAD_MUTEX_INITIALIZER;
static NSMutableDictionary *LGCPUProfilerMemoryCounters = nil;

void LGCPUProfilerRegisterMemoryCounter(NSString *name, uint64_t (^bytes)(void))
{
    if (![name isKindOfClass:[NSString class]] || name.length == 0 || name.length > 48 || bytes == nil)
        return;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_."];
    if ([name rangeOfCharacterFromSet:[allowed invertedSet]].location != NSNotFound)
        return;
    pthread_mutex_lock(&LGCPUProfilerMemoryCountersLock);
    if (LGCPUProfilerMemoryCounters == nil)
        LGCPUProfilerMemoryCounters = [[NSMutableDictionary alloc] init];
    if (LGCPUProfilerMemoryCounters[name] != nil || LGCPUProfilerMemoryCounters.count < 32)
        LGCPUProfilerMemoryCounters[name] = [bytes copy];
    pthread_mutex_unlock(&LGCPUProfilerMemoryCountersLock);
}

static NSDictionary *LGCPUProfilerMemoryCounterSnapshot(void)
{
    pthread_mutex_lock(&LGCPUProfilerMemoryCountersLock);
    NSDictionary *snapshot = [LGCPUProfilerMemoryCounters copy];
    pthread_mutex_unlock(&LGCPUProfilerMemoryCountersLock);
    return snapshot;
}
#if defined(LIGHTGRAM_ARMV6)
static OSSpinLock LGCPUProfilerGraphicsLock = OS_SPINLOCK_INIT;
static LGCPUProfilerFrameSlot LGCPUProfilerGraphicsCallers[LGCPUProfilerFrameSlots];
static uint32_t LGCPUProfilerGraphicsCount = 0;
#endif

static double LGCPUProfilerNow(void)
{
    return (double)mach_absolute_time() * LGCPUProfilerTickSeconds;
}

static void LGCPUProfilerResolveExecutable(void)
{
    const struct mach_header *header = _dyld_get_image_header(0);
    if (header == NULL)
        return;
    uintptr_t slide = (uintptr_t)_dyld_get_image_vmaddr_slide(0);
#if defined(__LP64__)
    const uint8_t *command = (const uint8_t *)header + sizeof(struct mach_header_64);
    uint32_t segmentCommand = LC_SEGMENT_64;
#else
    const uint8_t *command = (const uint8_t *)header + sizeof(struct mach_header);
    uint32_t segmentCommand = LC_SEGMENT;
#endif
    for (uint32_t index = 0; index < header->ncmds; index++)
    {
        const struct load_command *loadCommand = (const struct load_command *)command;
        if (loadCommand->cmd == segmentCommand)
        {
#if defined(__LP64__)
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
#else
            const struct segment_command *segment = (const struct segment_command *)command;
#endif
            if (strncmp(segment->segname, SEG_TEXT, sizeof(segment->segname)) == 0)
            {
                LGCPUProfilerSlide = slide;
                LGCPUProfilerTextStart = (uintptr_t)segment->vmaddr + slide;
                LGCPUProfilerTextEnd = LGCPUProfilerTextStart + (uintptr_t)segment->vmsize;
                return;
            }
        }
        command += loadCommand->cmdsize;
    }
}

static uintptr_t LGCPUProfilerCodeAddress(uintptr_t address)
{
#if defined(__LP64__)
    return address & 0x0000000FFFFFFFFFULL;
#else
    return address & ~(uintptr_t)1;
#endif
}

static bool LGCPUProfilerIsExecutableAddress(uintptr_t address)
{
    return address >= LGCPUProfilerTextStart && address < LGCPUProfilerTextEnd;
}

static void LGCPUProfilerResolveStack(LGCPUProfilerThread *thread)
{
    thread->stackLow = 0;
    thread->stackHigh = 0;
    if (LGCPUProfilerFromMachThread == NULL)
        return;
    pthread_t pthread = LGCPUProfilerFromMachThread(thread->port);
    if (pthread == NULL)
        return;
    uintptr_t high = (uintptr_t)pthread_get_stackaddr_np(pthread);
    size_t size = pthread_get_stacksize_np(pthread);
    if (high == 0 || size == 0 || size > high)
        return;
    thread->stackHigh = high;
    thread->stackLow = high - size;
}

static int LGCPUProfilerCaptureFrames(const LGCPUProfilerThread *thread, uintptr_t *frames, int capacity)
{
    int count = 0;
    uintptr_t pointer = 0;
#if defined(__arm64__)
    arm_thread_state64_t state;
    mach_msg_type_number_t stateCount = ARM_THREAD_STATE64_COUNT;
    if (thread_get_state(thread->port, ARM_THREAD_STATE64, (thread_state_t)&state, &stateCount) != KERN_SUCCESS)
        return 0;
    frames[count++] = LGCPUProfilerCodeAddress((uintptr_t)state.__pc);
    frames[count++] = LGCPUProfilerCodeAddress((uintptr_t)state.__lr);
    pointer = (uintptr_t)state.__fp;
#elif defined(__arm__)
    arm_thread_state_t state;
    mach_msg_type_number_t stateCount = ARM_THREAD_STATE_COUNT;
    if (thread_get_state(thread->port, ARM_THREAD_STATE, (thread_state_t)&state, &stateCount) != KERN_SUCCESS)
        return 0;
    frames[count++] = LGCPUProfilerCodeAddress((uintptr_t)state.__pc);
    frames[count++] = LGCPUProfilerCodeAddress((uintptr_t)state.__lr);
    pointer = (uintptr_t)state.__r[7];
#else
    return 0;
#endif
    while (count < capacity && thread->stackHigh != 0 && pointer >= thread->stackLow && pointer <= thread->stackHigh - 2 * sizeof(uintptr_t) && (pointer & (sizeof(uintptr_t) - 1)) == 0)
    {
        uintptr_t record[2];
        vm_size_t bytesRead = 0;
        if (vm_read_overwrite(mach_task_self(), (vm_address_t)pointer, sizeof(record), (vm_address_t)record, &bytesRead) != KERN_SUCCESS || bytesRead != sizeof(record))
            break;
        uintptr_t next = record[0];
        uintptr_t address = LGCPUProfilerCodeAddress(record[1]);
        if (address == 0 || next <= pointer)
            break;
        frames[count++] = address;
        pointer = next;
    }
    return count;
}

static void LGCPUProfilerCount(LGCPUProfilerThread *thread, LGCPUProfilerFrameSlot *slots, uintptr_t address)
{
    uintptr_t index = (address >> 2) % LGCPUProfilerFrameSlots;
    for (int probe = 0; probe < LGCPUProfilerFrameSlots; probe++)
    {
        LGCPUProfilerFrameSlot *slot = &slots[(index + probe) % LGCPUProfilerFrameSlots];
        if (slot->count == 0)
        {
            slot->address = address;
            slot->count = 1;
            return;
        }
        if (slot->address == address)
        {
            slot->count++;
            return;
        }
    }
    thread->overflow++;
}

static LGCPUProfilerFrameSlot LGCPUProfilerMainInclusive[LGCPUProfilerMainInclusiveSlots];
static uint32_t LGCPUProfilerMainInclusiveOverflow = 0;

static void LGCPUProfilerRecordMainInclusive(const uintptr_t *frames, int count)
{
    for (int index = 0; index < count; index++)
    {
        uintptr_t frame = frames[index];
        if (!LGCPUProfilerIsExecutableAddress(frame))
            continue;
        bool repeated = false;
        for (int previous = 0; previous < index; previous++)
        {
            if (frames[previous] == frame)
            {
                repeated = true;
                break;
            }
        }
        if (repeated)
            continue;
        uintptr_t address = frame - LGCPUProfilerSlide;
        uintptr_t slotIndex = (address >> 1) % LGCPUProfilerMainInclusiveSlots;
        bool stored = false;
        for (int probe = 0; probe < LGCPUProfilerMainInclusiveSlots; probe++)
        {
            LGCPUProfilerFrameSlot *slot = &LGCPUProfilerMainInclusive[(slotIndex + probe) % LGCPUProfilerMainInclusiveSlots];
            if (slot->count == 0)
            {
                slot->address = address;
                slot->count = 1;
                stored = true;
                break;
            }
            if (slot->address == address)
            {
                slot->count++;
                stored = true;
                break;
            }
        }
        if (!stored)
            LGCPUProfilerMainInclusiveOverflow++;
    }
}

static void LGCPUProfilerRecord(LGCPUProfilerThread *thread, const uintptr_t *frames, int count)
{
    if (count == 0)
        return;
    thread->samples++;
    if (thread->port == LGCPUProfilerMainThread)
        LGCPUProfilerRecordMainInclusive(frames, count);
    LGCPUProfilerCount(thread, thread->leafFrames, frames[0]);
    int first = LGCPUProfilerIsExecutableAddress(frames[0]) ? 0 : 1;
    bool foundCode = false;
    for (int index = first; index < count; index++)
    {
        if (!LGCPUProfilerIsExecutableAddress(frames[index]))
            continue;
        if (!foundCode)
        {
            LGCPUProfilerCount(thread, thread->codeFrames, frames[index] - LGCPUProfilerSlide);
            foundCode = true;
            continue;
        }
        LGCPUProfilerCount(thread, thread->callerFrames, frames[index] - LGCPUProfilerSlide);
        return;
    }
}

static void LGCPUProfilerAppendTopFrames(NSMutableString *line, LGCPUProfilerFrameSlot *slots);

#if defined(LIGHTGRAM_ARMV6)
static void LGCPUProfilerRecordOffMainGraphics(const void *caller)
{
    uintptr_t address = LGCPUProfilerCodeAddress((uintptr_t)caller);
    if (LGCPUProfilerIsExecutableAddress(address))
        address -= LGCPUProfilerSlide;
    OSSpinLockLock(&LGCPUProfilerGraphicsLock);
    LGCPUProfilerGraphicsCount++;
    uintptr_t index = (address >> 2) % LGCPUProfilerFrameSlots;
    for (int probe = 0; probe < LGCPUProfilerFrameSlots; probe++)
    {
        LGCPUProfilerFrameSlot *slot = &LGCPUProfilerGraphicsCallers[(index + probe) % LGCPUProfilerFrameSlots];
        if (slot->count == 0 || slot->address == address)
        {
            slot->address = address;
            slot->count++;
            break;
        }
    }
    OSSpinLockUnlock(&LGCPUProfilerGraphicsLock);
}

static void LGCPUProfilerReportOffMainGraphics(void)
{
    LGCPUProfilerFrameSlot callers[LGCPUProfilerFrameSlots];
    OSSpinLockLock(&LGCPUProfilerGraphicsLock);
    uint32_t count = LGCPUProfilerGraphicsCount;
    memcpy(callers, LGCPUProfilerGraphicsCallers, sizeof(callers));
    memset(LGCPUProfilerGraphicsCallers, 0, sizeof(LGCPUProfilerGraphicsCallers));
    LGCPUProfilerGraphicsCount = 0;
    OSSpinLockUnlock(&LGCPUProfilerGraphicsLock);
    if (count == 0)
        return;
    NSMutableString *line = [[NSMutableString alloc] initWithFormat:@"UIKITBG count=%u callers=", (unsigned int)count];
    LGCPUProfilerAppendTopFrames(line, callers);
    LGPlatformDiagnosticLog(@"%@", line);
}
#endif

static double LGCPUProfilerThreadTime(const thread_basic_info_data_t *info)
{
    return (double)info->user_time.seconds + (double)info->user_time.microseconds / 1000000.0 + (double)info->system_time.seconds + (double)info->system_time.microseconds / 1000000.0;
}

static LGCPUProfilerThread *LGCPUProfilerThreadForPort(thread_act_t port, bool *created)
{
    LGCPUProfilerThread *available = NULL;
    for (int index = 0; index < LGCPUProfilerMaximumThreads; index++)
    {
        LGCPUProfilerThread *thread = &LGCPUProfilerThreads[index];
        if (thread->used && thread->port == port)
        {
            *created = false;
            return thread;
        }
        if (!thread->used && available == NULL)
            available = thread;
    }
    if (available == NULL)
        return NULL;
    memset(available, 0, sizeof(*available));
    available->used = true;
    available->port = port;
    *created = true;
    return available;
}

static void LGCPUProfilerTick(bool initial)
{
    thread_act_array_t ports = NULL;
    mach_msg_type_number_t portCount = 0;
    if (task_threads(mach_task_self(), &ports, &portCount) != KERN_SUCCESS)
        return;

    for (int index = 0; index < LGCPUProfilerMaximumThreads; index++)
        LGCPUProfilerThreads[index].present = false;

    uintptr_t frames[LGCPUProfilerMaximumFrames];
    for (mach_msg_type_number_t index = 0; index < portCount; index++)
    {
        thread_act_t port = ports[index];
        bool retained = false;
        if (port != LGCPUProfilerSelfThread)
        {
            thread_basic_info_data_t info;
            mach_msg_type_number_t infoCount = THREAD_BASIC_INFO_COUNT;
            if (thread_info(port, THREAD_BASIC_INFO, (thread_info_t)&info, &infoCount) == KERN_SUCCESS)
            {
                bool created = false;
                LGCPUProfilerThread *thread = LGCPUProfilerThreadForPort(port, &created);
                if (thread != NULL)
                {
                    double time = LGCPUProfilerThreadTime(&info);
                    double previous = thread->current;
                    if (created)
                    {
                        retained = true;
                        thread->baseline = initial ? time : 0.0;
                        LGCPUProfilerResolveStack(thread);
                    }
                    thread->present = true;
                    thread->current = time;
                    if (!initial && !created && time > previous && info.run_state == TH_STATE_RUNNING && (info.flags & TH_FLAGS_IDLE) == 0 && thread_suspend(port) == KERN_SUCCESS)
                    {
                        int count = LGCPUProfilerCaptureFrames(thread, frames, LGCPUProfilerMaximumFrames);
                        thread_resume(port);
                        LGCPUProfilerRecord(thread, frames, count);
                    }
                }
            }
        }
        if (!retained)
            mach_port_deallocate(mach_task_self(), port);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)ports, portCount * sizeof(thread_act_t));
}

static NSString *LGCPUProfilerThreadLabel(const LGCPUProfilerThread *thread)
{
    if (thread->port == LGCPUProfilerMainThread)
        return @"main";
    if (thread->present && LGCPUProfilerGetName != NULL && LGCPUProfilerFromMachThread != NULL)
    {
        pthread_t pthread = LGCPUProfilerFromMachThread(thread->port);
        char name[64] = { 0 };
        if (pthread != NULL && LGCPUProfilerGetName(pthread, name, sizeof(name)) == 0 && name[0] != 0)
            return [[NSString alloc] initWithUTF8String:name];
    }
    return [[NSString alloc] initWithFormat:@"#%x", (unsigned int)thread->port];
}

static NSString *LGCPUProfilerThreadPriority(const LGCPUProfilerThread *thread)
{
    if (!thread->present)
        return @"-";
    policy_rr_info_data_t fixedInfo;
    mach_msg_type_number_t count = POLICY_RR_INFO_COUNT;
    if (thread_info(thread->port, THREAD_SCHED_RR_INFO, (thread_info_t)&fixedInfo, &count) == KERN_SUCCESS)
        return [[NSString alloc] initWithFormat:@"%df", fixedInfo.base_priority];
    policy_timeshare_info_data_t timeshareInfo;
    count = POLICY_TIMESHARE_INFO_COUNT;
    if (thread_info(thread->port, THREAD_SCHED_TIMESHARE_INFO, (thread_info_t)&timeshareInfo, &count) == KERN_SUCCESS)
        return [[NSString alloc] initWithFormat:@"%d/%d", timeshareInfo.cur_priority, timeshareInfo.base_priority];
    return @"?";
}

static void LGCPUProfilerAppendTopFrames(NSMutableString *line, LGCPUProfilerFrameSlot *slots)
{
    for (int rank = 0; rank < LGCPUProfilerReportedFrames; rank++)
    {
        LGCPUProfilerFrameSlot *best = NULL;
        for (int index = 0; index < LGCPUProfilerFrameSlots; index++)
        {
            if (slots[index].count != 0 && (best == NULL || slots[index].count > best->count))
                best = &slots[index];
        }
        if (best == NULL)
            return;
        [line appendFormat:@"%s0x%lx:%u", rank == 0 ? "" : ",", (unsigned long)best->address, (unsigned int)best->count];
        best->count = 0;
    }
}

static void LGCPUProfilerAppendLeafImages(NSMutableString *line, const LGCPUProfilerFrameSlot *slots)
{
    NSMutableArray *images = [[NSMutableArray alloc] init];
    uint32_t counts[LGCPUProfilerFrameSlots];
    for (int index = 0; index < LGCPUProfilerFrameSlots; index++)
    {
        if (slots[index].count == 0)
            continue;
        NSString *image = nil;
        if (LGCPUProfilerIsExecutableAddress(slots[index].address))
            image = @"app";
        else
        {
            Dl_info info;
            memset(&info, 0, sizeof(info));
            if (dladdr((const void *)slots[index].address, &info) != 0 && info.dli_fname != NULL)
            {
                const char *name = strrchr(info.dli_fname, '/');
                image = [[NSString alloc] initWithFormat:@"%s`%s", name == NULL ? info.dli_fname : name + 1, info.dli_sname == NULL ? "?" : info.dli_sname];
            }
            else
                image = @"?";
        }
        NSUInteger position = [images indexOfObject:image];
        if (position == NSNotFound)
        {
            counts[images.count] = slots[index].count;
            [images addObject:image];
        }
        else
            counts[position] += slots[index].count;
    }
    for (int rank = 0; rank < LGCPUProfilerReportedImages; rank++)
    {
        NSUInteger best = NSNotFound;
        for (NSUInteger index = 0; index < images.count; index++)
        {
            if (counts[index] != 0 && (best == NSNotFound || counts[index] > counts[best]))
                best = index;
        }
        if (best == NSNotFound)
            return;
        [line appendFormat:@"%s%@:%u", rank == 0 ? "" : ",", images[best], (unsigned int)counts[best]];
        counts[best] = 0;
    }
}

extern long long sqlite3_memory_used(void);
extern long long sqlite3_memory_highwater(int resetFlag);

static const size_t LGMemoryGrowthReportThreshold = 768 * 1024;

LGMemoryGrowthSample LGMemoryGrowthBegin(void)
{
    malloc_statistics_t heap;
    memset(&heap, 0, sizeof(heap));
    malloc_zone_statistics(NULL, &heap);
    LGMemoryGrowthSample sample = { heap.size_in_use, heap.size_allocated, mach_absolute_time() };
    return sample;
}

void LGMemoryGrowthEnd(LGMemoryGrowthSample sample, const char *queue, const char *file, int line)
{
    malloc_statistics_t heap;
    memset(&heap, 0, sizeof(heap));
    malloc_zone_statistics(NULL, &heap);
    long long reservedDelta = (long long)heap.size_allocated - (long long)sample.reserved;
    long long inUseDelta = (long long)heap.size_in_use - (long long)sample.inUse;
    if (reservedDelta < (long long)LGMemoryGrowthReportThreshold && inUseDelta < (long long)LGMemoryGrowthReportThreshold)
        return;
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    double milliseconds = (double)(mach_absolute_time() - sample.ticks) * (double)timebase.numer / (double)timebase.denom / 1000000.0;
    const char *fileName = file == NULL ? "?" : (strrchr(file, '/') != NULL ? strrchr(file, '/') + 1 : file);
    LGPlatformDiagnosticLog(@"MEMGROW queue=%s site=%s:%d reserved_kb=%+lld inuse_kb=%+lld heap_kb=%u reserved_total_kb=%u ms=%.0f", queue, fileName, line, reservedDelta / 1024, inUseDelta / 1024, (unsigned int)(heap.size_in_use / 1024), (unsigned int)(heap.size_allocated / 1024), milliseconds);
}

typedef void (LGHeapProfilerLoggerFunction)(uint32_t type, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3, uintptr_t result, uint32_t skippedFrames);

enum
{
    LGHeapProfilerLiveCapacity = 16384,
    LGHeapProfilerSiteCapacity = 1024,
    LGHeapProfilerSiteSlots = 2048,
    LGHeapProfilerReportedSites = 20,
    LGHeapProfilerFrameDepth = 24,
    LGHeapProfilerTypeAllocate = 2,
    LGHeapProfilerTypeDeallocate = 4,
    LGHeapProfilerTypeHasZone = 8,
    LGHeapProfilerSmallSampleShift = 6,
    LGHeapProfilerSampledFlag = 0x80000000u
};

static const uintptr_t LGHeapProfilerThreshold = 16 * 1024;

typedef struct
{
    uintptr_t pointer;
    uint32_t size;
    uint32_t site;
} LGHeapProfilerLiveEntry;

typedef struct
{
    uintptr_t address;
    uint64_t liveBytes;
    uint64_t peakBytes;
    uint32_t liveCount;
    uint32_t allocations;
} LGHeapProfilerSite;

static LGHeapProfilerLiveEntry LGHeapProfilerLive[LGHeapProfilerLiveCapacity];
static LGHeapProfilerSite LGHeapProfilerSites[LGHeapProfilerSiteCapacity];
static LGHeapProfilerSite LGHeapProfilerSnapshot[LGHeapProfilerSiteCapacity];
static uint32_t LGHeapProfilerSiteIndices[LGHeapProfilerSiteSlots];
static uint32_t LGHeapProfilerSiteCount = 0;
static uint32_t LGHeapProfilerLiveCount = 0;
static uint64_t LGHeapProfilerLiveBytes = 0;
static uint64_t LGHeapProfilerPeakBytes = 0;
static uint32_t LGHeapProfilerDropped = 0;
static uint64_t LGHeapProfilerSmallSampledBytes = 0;
static OSSpinLock LGHeapProfilerLock = OS_SPINLOCK_INIT;
static LGHeapProfilerLoggerFunction *LGHeapProfilerPreviousLogger = NULL;

static inline bool LGHeapProfilerSampledPointer(uintptr_t pointer)
{
    return ((uint32_t)((pointer >> 4) * 2654435761u) >> (32 - LGHeapProfilerSmallSampleShift)) == 0;
}

static inline uint32_t LGHeapProfilerPointerSlot(uintptr_t pointer)
{
    return (uint32_t)((pointer >> 12) * 2654435761u) & (LGHeapProfilerLiveCapacity - 1);
}

static uint32_t LGHeapProfilerSiteForAddressLocked(uintptr_t address)
{
    uint32_t slot = (uint32_t)((address >> 2) * 2654435761u) & (LGHeapProfilerSiteSlots - 1);
    for (uint32_t probe = 0; probe < LGHeapProfilerSiteSlots; probe++)
    {
        uint32_t stored = LGHeapProfilerSiteIndices[slot];
        if (stored == 0)
        {
            if (LGHeapProfilerSiteCount >= LGHeapProfilerSiteCapacity)
                return 0;
            LGHeapProfilerSites[LGHeapProfilerSiteCount].address = address;
            LGHeapProfilerSiteCount++;
            LGHeapProfilerSiteIndices[slot] = LGHeapProfilerSiteCount;
            return LGHeapProfilerSiteCount;
        }
        if (LGHeapProfilerSites[stored - 1].address == address)
            return stored;
        slot = (slot + 1) & (LGHeapProfilerSiteSlots - 1);
    }
    return 0;
}

static void LGHeapProfilerRemoveLocked(uintptr_t pointer)
{
    uint32_t index = LGHeapProfilerPointerSlot(pointer);
    for (uint32_t probe = 0; probe < LGHeapProfilerLiveCapacity; probe++)
    {
        uintptr_t stored = LGHeapProfilerLive[index].pointer;
        if (stored == 0)
            return;
        if (stored == pointer)
            break;
        index = (index + 1) & (LGHeapProfilerLiveCapacity - 1);
    }
    if (LGHeapProfilerLive[index].pointer != pointer)
        return;

    LGHeapProfilerLiveEntry entry = LGHeapProfilerLive[index];
    bool sampled = (entry.site & LGHeapProfilerSampledFlag) != 0;
    uint32_t siteIndex = entry.site & ~LGHeapProfilerSampledFlag;
    uint64_t weightedSize = sampled ? ((uint64_t)entry.size << LGHeapProfilerSmallSampleShift) : entry.size;
    if (siteIndex != 0)
    {
        LGHeapProfilerSite *site = &LGHeapProfilerSites[siteIndex - 1];
        site->liveBytes -= weightedSize;
        site->liveCount--;
    }
    if (sampled)
        LGHeapProfilerSmallSampledBytes -= entry.size;
    else
        LGHeapProfilerLiveBytes -= entry.size;
    LGHeapProfilerLiveCount--;

    uint32_t hole = index;
    uint32_t next = index;
    for (;;)
    {
        next = (next + 1) & (LGHeapProfilerLiveCapacity - 1);
        uintptr_t candidate = LGHeapProfilerLive[next].pointer;
        if (candidate == 0)
            break;
        uint32_t home = LGHeapProfilerPointerSlot(candidate);
        bool movable = hole <= next ? (home <= hole || home > next) : (home <= hole && home > next);
        if (movable)
        {
            LGHeapProfilerLive[hole] = LGHeapProfilerLive[next];
            hole = next;
        }
    }
    LGHeapProfilerLive[hole].pointer = 0;
}

static void LGHeapProfilerInsertLocked(uintptr_t pointer, uintptr_t size, uintptr_t address, bool sampled)
{
    if (LGHeapProfilerLiveCount >= LGHeapProfilerLiveCapacity / 2)
    {
        LGHeapProfilerDropped++;
        return;
    }
    uint32_t index = LGHeapProfilerPointerSlot(pointer);
    while (LGHeapProfilerLive[index].pointer != 0)
        index = (index + 1) & (LGHeapProfilerLiveCapacity - 1);

    uint32_t site = address == 0 ? 0 : LGHeapProfilerSiteForAddressLocked(address);
    uint64_t weightedSize = sampled ? ((uint64_t)size << LGHeapProfilerSmallSampleShift) : size;
    LGHeapProfilerLive[index].pointer = pointer;
    LGHeapProfilerLive[index].size = (uint32_t)size;
    LGHeapProfilerLive[index].site = site | (sampled ? LGHeapProfilerSampledFlag : 0);
    LGHeapProfilerLiveCount++;
    if (sampled)
        LGHeapProfilerSmallSampledBytes += size;
    else
        LGHeapProfilerLiveBytes += size;
    if (LGHeapProfilerLiveBytes > LGHeapProfilerPeakBytes)
        LGHeapProfilerPeakBytes = LGHeapProfilerLiveBytes;
    if (site != 0)
    {
        LGHeapProfilerSite *entry = &LGHeapProfilerSites[site - 1];
        entry->liveBytes += weightedSize;
        entry->liveCount++;
        entry->allocations++;
        if (entry->liveBytes > entry->peakBytes)
            entry->peakBytes = entry->liveBytes;
    }
}

__attribute__((noinline)) static uintptr_t LGHeapProfilerCallSite(void)
{
    uintptr_t *frame = (uintptr_t *)__builtin_frame_address(0);
    for (int depth = 0; depth < LGHeapProfilerFrameDepth && frame != NULL; depth++)
    {
        uintptr_t *next = (uintptr_t *)frame[0];
        uintptr_t returnAddress = frame[1];
        if (depth >= 2 && LGCPUProfilerIsExecutableAddress(returnAddress))
            return returnAddress;
        if (next <= frame || (uintptr_t)next - (uintptr_t)frame > 1024 * 1024 || ((uintptr_t)next & (sizeof(uintptr_t) - 1)) != 0)
            break;
        frame = next;
    }
    return 0;
}

static void LGHeapProfilerLogger(uint32_t type, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3, uintptr_t result, uint32_t skippedFrames)
{
    if (LGHeapProfilerPreviousLogger != NULL)
        LGHeapProfilerPreviousLogger(type, arg1, arg2, arg3, result, skippedFrames + 1);

    bool allocate = (type & LGHeapProfilerTypeAllocate) != 0;
    bool deallocate = (type & LGHeapProfilerTypeDeallocate) != 0;
    if (!allocate && !deallocate)
        return;
    bool hasZone = (type & LGHeapProfilerTypeHasZone) != 0;
    uintptr_t freed = deallocate ? (hasZone ? arg2 : arg1) : 0;
    uintptr_t size = allocate ? (deallocate ? (hasZone ? arg3 : arg2) : (hasZone ? arg2 : arg1)) : 0;
    bool trackFree = freed != 0 && ((freed & 0xfff) == 0 || LGHeapProfilerSampledPointer(freed));
    bool large = size >= LGHeapProfilerThreshold;
    bool trackAllocation = allocate && result != 0 && size != 0 && (large || LGHeapProfilerSampledPointer(result));
    if (!trackFree && !trackAllocation)
        return;

    uintptr_t address = trackAllocation ? LGHeapProfilerCallSite() : 0;
    OSSpinLockLock(&LGHeapProfilerLock);
    if (trackFree)
        LGHeapProfilerRemoveLocked(freed);
    if (trackAllocation)
        LGHeapProfilerInsertLocked(result, size, address, !large);
    OSSpinLockUnlock(&LGHeapProfilerLock);
}

static void LGHeapProfilerInstall(void)
{
    LGHeapProfilerLoggerFunction **logger = (LGHeapProfilerLoggerFunction **)dlsym(RTLD_DEFAULT, "malloc_logger");
    if (logger == NULL)
    {
        LGPlatformDiagnosticLog(@"HEAPTOP unavailable");
        return;
    }
    LGHeapProfilerPreviousLogger = *logger;
    *logger = LGHeapProfilerLogger;
}

static void LGHeapProfilerReport(const char *reason)
{
    OSSpinLockLock(&LGHeapProfilerLock);
    uint32_t siteCount = LGHeapProfilerSiteCount;
    memcpy(LGHeapProfilerSnapshot, LGHeapProfilerSites, sizeof(LGHeapProfilerSite) * siteCount);
    uint64_t liveBytes = LGHeapProfilerLiveBytes;
    uint64_t peakBytes = LGHeapProfilerPeakBytes;
    uint32_t liveCount = LGHeapProfilerLiveCount;
    uint32_t dropped = LGHeapProfilerDropped;
    uint64_t smallEstimate = LGHeapProfilerSmallSampledBytes << LGHeapProfilerSmallSampleShift;
    OSSpinLockUnlock(&LGHeapProfilerLock);

    NSMutableString *line = [[NSMutableString alloc] initWithFormat:@"HEAPTOP reason=%s live_kb=%llu peak_kb=%llu small_estimate_kb=%llu blocks=%u dropped=%u sites=", reason, liveBytes / 1024, peakBytes / 1024, smallEstimate / 1024, liveCount, dropped];
    for (int rank = 0; rank < LGHeapProfilerReportedSites; rank++)
    {
        uint32_t best = UINT32_MAX;
        for (uint32_t index = 0; index < siteCount; index++)
        {
            if (LGHeapProfilerSnapshot[index].peakBytes == 0)
                continue;
            if (best == UINT32_MAX || LGHeapProfilerSnapshot[index].liveBytes > LGHeapProfilerSnapshot[best].liveBytes || (LGHeapProfilerSnapshot[index].liveBytes == LGHeapProfilerSnapshot[best].liveBytes && LGHeapProfilerSnapshot[index].peakBytes > LGHeapProfilerSnapshot[best].peakBytes))
                best = index;
        }
        if (best == UINT32_MAX)
            break;
        LGHeapProfilerSite *site = &LGHeapProfilerSnapshot[best];
        [line appendFormat:@"%s0x%lx:%llu/%u/%llu/%u", rank == 0 ? "" : ",", (unsigned long)(site->address - LGCPUProfilerSlide), site->liveBytes / 1024, site->liveCount, site->peakBytes / 1024, site->allocations];
        site->peakBytes = 0;
        site->liveBytes = 0;
    }
    LGPlatformDiagnosticLog(@"%@", line);
}

static void LGCPUProfilerReportMemory(double window)
{
    static bool initialized = false;
    static integer_t previousFaults = 0;
    static integer_t previousPageins = 0;
    task_basic_info_data_t basic;
    mach_msg_type_number_t basicCount = TASK_BASIC_INFO_COUNT;
    task_events_info_data_t events;
    mach_msg_type_number_t eventsCount = TASK_EVENTS_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&basic, &basicCount) != KERN_SUCCESS || task_info(mach_task_self(), TASK_EVENTS_INFO, (task_info_t)&events, &eventsCount) != KERN_SUCCESS)
        return;
    malloc_statistics_t heap;
    memset(&heap, 0, sizeof(heap));
    malloc_zone_statistics(NULL, &heap);
    int threads = 0;
    for (int index = 0; index < LGCPUProfilerMaximumThreads; index++)
    {
        if (LGCPUProfilerThreads[index].used && LGCPUProfilerThreads[index].present)
            threads++;
    }
    static uint32_t reports = 0;
    if (initialized && (++reports % 6) == 0)
        LGHeapProfilerReport("periodic");
    if (initialized)
    {
        NSMutableString *line = [[NSMutableString alloc] initWithFormat:@"MEMSTAT window_ms=%.0f resident_kb=%u virtual_kb=%u heap_kb=%u heap_allocated_kb=%u sqlite_kb=%lld sqlite_peak_kb=%lld faults=%d pageins=%d threads=%d", window * 1000.0, (unsigned int)(basic.resident_size / 1024), (unsigned int)(basic.virtual_size / 1024), (unsigned int)(heap.size_in_use / 1024), (unsigned int)(heap.size_allocated / 1024), sqlite3_memory_used() / 1024, sqlite3_memory_highwater(0) / 1024, (int)(events.faults - previousFaults), (int)(events.pageins - previousPageins), threads];
        NSDictionary *counters = LGCPUProfilerMemoryCounterSnapshot();
        NSArray *names = [[counters allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *name in names)
        {
            uint64_t (^counter)(void) = counters[name];
            uint64_t value = counter();
            if ([name hasPrefix:@"count."])
                [line appendFormat:@" %@=%llu", name, (unsigned long long)value];
            else
                [line appendFormat:@" %@_kb=%llu", name, (unsigned long long)(value / 1024)];
        }
        LGPlatformDiagnosticLog(@"%@", line);
    }
    initialized = true;
    previousFaults = events.faults;
    previousPageins = events.pageins;
}

static void LGCPUProfilerReport(double window)
{
    LGCPUProfilerThread *ranked[LGCPUProfilerMaximumThreads];
    int rankedCount = 0;
    double total = 0.0;
    for (int index = 0; index < LGCPUProfilerMaximumThreads; index++)
    {
        LGCPUProfilerThread *thread = &LGCPUProfilerThreads[index];
        if (!thread->used)
            continue;
        double delta = MAX(0.0, thread->current - thread->baseline);
        total += delta;
        if (delta >= 0.02)
            ranked[rankedCount++] = thread;
    }
    for (int outer = 1; outer < rankedCount; outer++)
    {
        LGCPUProfilerThread *thread = ranked[outer];
        double delta = thread->current - thread->baseline;
        int inner = outer - 1;
        while (inner >= 0 && ranked[inner]->current - ranked[inner]->baseline < delta)
        {
            ranked[inner + 1] = ranked[inner];
            inner--;
        }
        ranked[inner + 1] = thread;
    }

    if (total >= window * LGCPUProfilerReportLoad)
    {
        NSMutableString *summary = [[NSMutableString alloc] initWithFormat:@"CPUSTAT window_ms=%.0f cpu_ms=%.0f threads=", window * 1000.0, total * 1000.0];
        for (int index = 0; index < rankedCount; index++)
            [summary appendFormat:@"%s%@:%.0f@%@", index == 0 ? "" : ",", LGCPUProfilerThreadLabel(ranked[index]), (ranked[index]->current - ranked[index]->baseline) * 1000.0, LGCPUProfilerThreadPriority(ranked[index])];
        LGPlatformDiagnosticLog(@"%@", summary);

        int reported = MIN(rankedCount, (int)LGCPUProfilerReportedThreads);
        for (int index = 0; index < reported; index++)
        {
            LGCPUProfilerThread *thread = ranked[index];
            if (thread->samples == 0)
                continue;
            NSMutableString *line = [[NSMutableString alloc] initWithFormat:@"CPUHOT thread=%@ cpu_ms=%.0f samples=%u overflow=%u images=", LGCPUProfilerThreadLabel(thread), (thread->current - thread->baseline) * 1000.0, (unsigned int)thread->samples, (unsigned int)thread->overflow];
            LGCPUProfilerAppendLeafImages(line, thread->leafFrames);
            [line appendString:@" code="];
            LGCPUProfilerAppendTopFrames(line, thread->codeFrames);
            [line appendString:@" caller="];
            LGCPUProfilerAppendTopFrames(line, thread->callerFrames);
            LGPlatformDiagnosticLog(@"%@", line);
        }
    }
    for (int index = 0; index < LGCPUProfilerMaximumThreads; index++)
    {
        LGCPUProfilerThread *thread = &LGCPUProfilerThreads[index];
        if (!thread->used || thread->port != LGCPUProfilerMainThread || thread->samples == 0)
            continue;
        NSMutableString *line = [[NSMutableString alloc] initWithFormat:@"CPUMAIN cpu_ms=%.0f samples=%u overflow=%u inclusive=", (thread->current - thread->baseline) * 1000.0, (unsigned int)thread->samples, (unsigned int)LGCPUProfilerMainInclusiveOverflow];
        for (int rank = 0; rank < LGCPUProfilerMainReportedFrames; rank++)
        {
            LGCPUProfilerFrameSlot *best = NULL;
            for (int slot = 0; slot < LGCPUProfilerMainInclusiveSlots; slot++)
            {
                if (LGCPUProfilerMainInclusive[slot].count != 0 && (best == NULL || LGCPUProfilerMainInclusive[slot].count > best->count))
                    best = &LGCPUProfilerMainInclusive[slot];
            }
            if (best == NULL)
                break;
            [line appendFormat:@"%s0x%lx:%u", rank == 0 ? "" : ",", (unsigned long)best->address, (unsigned int)best->count];
            best->count = 0;
        }
        LGPlatformDiagnosticLog(@"%@", line);
    }
    memset(LGCPUProfilerMainInclusive, 0, sizeof(LGCPUProfilerMainInclusive));
    LGCPUProfilerMainInclusiveOverflow = 0;
    LGCPUProfilerReportMemory(window);

    for (int index = 0; index < LGCPUProfilerMaximumThreads; index++)
    {
        LGCPUProfilerThread *thread = &LGCPUProfilerThreads[index];
        if (!thread->used)
            continue;
        if (!thread->present)
        {
            mach_port_deallocate(mach_task_self(), thread->port);
            memset(thread, 0, sizeof(*thread));
            continue;
        }
        thread->baseline = thread->current;
        thread->samples = 0;
        thread->overflow = 0;
        memset(thread->codeFrames, 0, sizeof(thread->codeFrames));
        memset(thread->callerFrames, 0, sizeof(thread->callerFrames));
        memset(thread->leafFrames, 0, sizeof(thread->leafFrames));
    }
}

static void LGCPUProfilerConfigureThread(void)
{
    pthread_t thread = pthread_self();
    int policy = 0;
    struct sched_param parameters;
    if (pthread_getschedparam(thread, &policy, &parameters) == 0)
    {
        int priority = sched_get_priority_max(policy);
        if (priority != -1)
        {
            parameters.sched_priority = priority;
            pthread_setschedparam(thread, policy, &parameters);
        }
    }
    thread_extended_policy_data_t extended;
    extended.timeshare = false;
    thread_policy_set(pthread_mach_thread_np(thread), THREAD_EXTENDED_POLICY, (thread_policy_t)&extended, THREAD_EXTENDED_POLICY_COUNT);
}

static void *LGCPUProfilerThreadMain(void *__unused argument)
{
    LGCPUProfilerSelfThread = pthread_mach_thread_np(pthread_self());
    LGCPUProfilerConfigureThread();
    LGPlatformDiagnosticLog(@"CPUPROFILER start text=0x%lx-0x%lx slide=0x%lx interval_ms=%u", (unsigned long)(LGCPUProfilerTextStart - LGCPUProfilerSlide), (unsigned long)(LGCPUProfilerTextEnd - LGCPUProfilerSlide), (unsigned long)LGCPUProfilerSlide, (unsigned int)(LGCPUProfilerSampleInterval / 1000));

    LGCPUProfilerTick(true);
    double windowStart = LGCPUProfilerNow();
    for (;;)
    {
        usleep(LGCPUProfilerSampleInterval);
        LGCPUProfilerTick(false);
        double now = LGCPUProfilerNow();
        if (now - windowStart >= LGCPUProfilerWindow)
        {
            @autoreleasepool
            {
                LGCPUProfilerReport(now - windowStart);
#if defined(LIGHTGRAM_ARMV6)
                LGCPUProfilerReportOffMainGraphics();
#endif
            }
            windowStart = now;
        }
    }
    return NULL;
}

void LGCPUProfilerStart(void)
{
    static bool started = false;
    if (started)
        return;
    started = true;

    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    LGCPUProfilerTickSeconds = (double)timebase.numer / (double)timebase.denom / 1000000000.0;
    LGCPUProfilerMainThread = pthread_mach_thread_np(pthread_self());
    LGCPUProfilerGetName = (LGCPUProfilerGetNameFunction)dlsym(RTLD_DEFAULT, "pthread_getname_np");
    LGCPUProfilerFromMachThread = (LGCPUProfilerFromMachThreadFunction)dlsym(RTLD_DEFAULT, "pthread_from_mach_thread_np");
    LGCPUProfilerResolveExecutable();
    LGHeapProfilerInstall();
    [[NSNotificationCenter defaultCenter] addObserverForName:@"UIApplicationDidReceiveMemoryWarningNotification" object:nil queue:nil usingBlock:^(__unused NSNotification *notification)
    {
        LGHeapProfilerReport("memory_warning");
    }];
#if defined(LIGHTGRAM_ARMV6)
    LightGramIOS3OffMainGraphicsHandler = LGCPUProfilerRecordOffMainGraphics;
#endif

    pthread_t profiler;
    if (pthread_create(&profiler, NULL, LGCPUProfilerThreadMain, NULL) == 0)
        pthread_detach(profiler);
}
