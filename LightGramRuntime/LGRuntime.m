#import "LGRuntime.h"
#import "LGDatabaseRuntime.h"
#import "../LightGramPlatform/LGPlatformDispatch.h"
#import "../LightGramPlatform/LGStructuralKey.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#include <float.h>
#include <unistd.h>
#include <pthread.h>
#include <sched.h>
#include <mach/mach.h>
#include <mach/thread_policy.h>
#include <mach/mach_time.h>
#include <mach/thread_switch.h>
#include <time.h>
#include <libkern/OSAtomic.h>

static volatile int LGRuntimeInteractionFastFlag = 0;
static volatile int LGRuntimeStartupPhaseCompletedFlag = 0;
static volatile int LGRuntimeFirstFrameCompletedFlag = 0;
static const NSTimeInterval LGRuntimeStartupPhaseTimeout = 30.0;
static const NSTimeInterval LGRuntimeFirstFrameTimeout = 12.0;
static const NSTimeInterval LGRuntimeStartupSyncQuietInterval = 0.75;
static volatile int32_t LGRuntimeStartupSyncFinishedFlag = 0;
static volatile int32_t LGRuntimeSyncActivityCount = 0;
static volatile int32_t LGRuntimeStartupSyncGeneration = 0;

@class LGRuntimeState;

@interface LGRuntimeGate : NSObject
{
    pthread_mutex_t _lock;
    __unsafe_unretained LGRuntimeState *_state;
    volatile int *_completedFlag;
    NSTimeInterval _timeout;
    NSMutableArray *_deferredTasks;
    BOOL _completed;
    uint64_t _timeoutGeneration;
}
- (instancetype)initWithState:(LGRuntimeState *)state timeout:(NSTimeInterval)timeout completedFlag:(volatile int *)completedFlag;
- (void)dispatchPriority:(LGRuntimePriority)priority block:(dispatch_block_t)block;
- (void)complete;
- (void)extend;
@end

@interface LGRuntimeState : NSObject
{
    pthread_mutex_t _lock;
    dispatch_queue_t _interactiveQueue;
    dispatch_queue_t _userQueue;
    dispatch_queue_t _storageQueue;
    dispatch_queue_t _utilityQueue;
    dispatch_queue_t _maintenanceQueue;
    dispatch_queue_t _transferQueue;
    dispatch_queue_t _backgroundTargetQueue;
    NSMutableDictionary *_tokens;
    uint64_t _nextToken;
    NSUInteger _interactionCount;
    NSMutableDictionary *_preloadBlocks;
    NSMutableArray *_preloadKeys;
    NSUInteger _preloadKeyOffset;
    NSUInteger _preloadRunningCount;
    NSUInteger _preloadWorkerLimit;
    BOOL _preloadCoolingDown;
    BOOL _suspendsBackgroundWorkDuringInteraction;
    LGRuntimeGate *_startupGate;
    LGRuntimeGate *_firstFrameGate;
}
- (void)beginInteraction;
- (void)enqueuePreload:(id<NSCopying>)key block:(dispatch_block_t)block;
- (void)drainPreloadsLocked;
- (void)endInteraction;
- (BOOL)interactionActive;
- (dispatch_queue_t)queueForPriority:(LGRuntimePriority)priority;
- (dispatch_queue_t)transferQueue;
- (void)dispatchPriority:(LGRuntimePriority)priority block:(dispatch_block_t)block;
- (void)dispatchPriority:(LGRuntimePriority)priority after:(NSTimeInterval)delay block:(dispatch_block_t)block;
- (void)dispatchCoalesced:(NSString *)key priority:(LGRuntimePriority)priority delay:(NSTimeInterval)delay block:(dispatch_block_t)block;
- (void)cancelCoalesced:(NSString *)key;
- (LGRuntimeGate *)startupGate;
- (LGRuntimeGate *)firstFrameGate;
- (uint64_t)nextToken;
@end

@implementation LGRuntimeGate

- (instancetype)initWithState:(LGRuntimeState *)state timeout:(NSTimeInterval)timeout completedFlag:(volatile int *)completedFlag
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_lock, NULL);
        _state = state;
        _timeout = timeout;
        _completedFlag = completedFlag;
        _deferredTasks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)completeLocked
{
    if (_completed)
        return;

    _completed = YES;
    *_completedFlag = 1;

    NSArray *tasks = _deferredTasks;
    _deferredTasks = [[NSMutableArray alloc] init];
    for (NSArray *task in tasks)
        [_state dispatchPriority:(LGRuntimePriority)[[task objectAtIndex:0] intValue] block:[task objectAtIndex:1]];
}

- (void)scheduleTimeoutLocked
{
    _timeoutGeneration++;
    uint64_t generation = _timeoutGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_timeout * (NSTimeInterval)NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        pthread_mutex_lock(&_lock);
        if (generation == _timeoutGeneration)
            [self completeLocked];
        pthread_mutex_unlock(&_lock);
    });
}

- (void)dispatchPriority:(LGRuntimePriority)priority block:(dispatch_block_t)block
{
    if (block == nil)
        return;

    dispatch_block_t deferredBlock = [block copy];
    pthread_mutex_lock(&_lock);
    if (_completed)
    {
        pthread_mutex_unlock(&_lock);
        [_state dispatchPriority:priority block:deferredBlock];
        return;
    }
    [_deferredTasks addObject:[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:(int)priority], deferredBlock, nil]];
    if (_timeoutGeneration == 0)
        [self scheduleTimeoutLocked];
    pthread_mutex_unlock(&_lock);
}

- (void)complete
{
    pthread_mutex_lock(&_lock);
    [self completeLocked];
    pthread_mutex_unlock(&_lock);
}

- (void)extend
{
    pthread_mutex_lock(&_lock);
    if (!_completed)
        [self scheduleTimeoutLocked];
    pthread_mutex_unlock(&_lock);
}

@end

@implementation LGRuntimeState

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_lock, NULL);
        _interactiveQueue = dispatch_queue_create("dev.notdevv.LightGram.runtime.interactive", DISPATCH_QUEUE_SERIAL);
        _userQueue = dispatch_queue_create("dev.notdevv.LightGram.runtime.user", DISPATCH_QUEUE_SERIAL);
        _storageQueue = dispatch_queue_create("dev.notdevv.LightGram.runtime.storage", DISPATCH_QUEUE_SERIAL);
        _utilityQueue = dispatch_queue_create("dev.notdevv.LightGram.runtime.utility", DISPATCH_QUEUE_SERIAL);
        _maintenanceQueue = dispatch_queue_create("dev.notdevv.LightGram.runtime.maintenance", DISPATCH_QUEUE_SERIAL);
        _transferQueue = dispatch_queue_create("dev.notdevv.LightGram.runtime.transfer", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_transferQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));

        int cpuCount = 1;
        size_t cpuSize = sizeof(cpuCount);
        if (sysctlbyname("hw.ncpu", &cpuCount, &cpuSize, NULL, 0) != 0 || cpuCount < 1)
            cpuCount = 1;

        _suspendsBackgroundWorkDuringInteraction = cpuCount == 1;

        dispatch_set_target_queue(_interactiveQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        dispatch_set_target_queue(_userQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));

        if (cpuCount <= 2)
        {
            _backgroundTargetQueue = dispatch_queue_create("dev.notdevv.LightGram.runtime.background", DISPATCH_QUEUE_SERIAL);
            dispatch_set_target_queue(_backgroundTargetQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
            dispatch_set_target_queue(_storageQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
            dispatch_set_target_queue(_utilityQueue, _backgroundTargetQueue);
            dispatch_set_target_queue(_maintenanceQueue, _backgroundTargetQueue);
        }
        else
        {
            dispatch_set_target_queue(_storageQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
            dispatch_set_target_queue(_utilityQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
            dispatch_set_target_queue(_maintenanceQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
        }

        _preloadBlocks = LGStructuralKeyDictionaryCreate();
        _preloadKeys = [[NSMutableArray alloc] init];
        _preloadWorkerLimit = (NSUInteger)MIN(4, MAX(1, cpuCount - 1));
        if (LGPlatformUsesConstrainedBackgroundExecution())
            _preloadWorkerLimit = 1;
        _tokens = [[NSMutableDictionary alloc] init];
        _nextToken = 1;
        _startupGate = [[LGRuntimeGate alloc] initWithState:self timeout:LGRuntimeStartupPhaseTimeout completedFlag:&LGRuntimeStartupPhaseCompletedFlag];
        _firstFrameGate = [[LGRuntimeGate alloc] initWithState:self timeout:LGRuntimeFirstFrameTimeout completedFlag:&LGRuntimeFirstFrameCompletedFlag];
    }
    return self;
}

- (LGRuntimeGate *)startupGate
{
    return _startupGate;
}

- (LGRuntimeGate *)firstFrameGate
{
    return _firstFrameGate;
}

- (void)beginInteraction
{
    pthread_mutex_lock(&_lock);
    _interactionCount++;
    LGRuntimeInteractionFastFlag = 1;
    if (_interactionCount == 1 && _suspendsBackgroundWorkDuringInteraction)
    {
        dispatch_suspend(_utilityQueue);
        dispatch_suspend(_maintenanceQueue);
    }
    pthread_mutex_unlock(&_lock);
}

- (void)endInteraction
{
    pthread_mutex_lock(&_lock);
    if (_interactionCount != 0)
    {
        _interactionCount--;
        LGRuntimeInteractionFastFlag = _interactionCount != 0 ? 1 : 0;
        if (_interactionCount == 0 && _suspendsBackgroundWorkDuringInteraction)
        {
            dispatch_resume(_maintenanceQueue);
            dispatch_resume(_utilityQueue);
        }
        [self drainPreloadsLocked];
    }
    pthread_mutex_unlock(&_lock);
}

- (void)enqueuePreload:(id<NSCopying>)key block:(dispatch_block_t)block
{
    if (key == nil || block == nil)
        return;
    id<NSCopying> taskKey = [key copyWithZone:NULL];
    dispatch_block_t taskBlock = [block copy];
    pthread_mutex_lock(&_lock);
    if ([_preloadBlocks objectForKey:taskKey] == nil)
        [_preloadKeys addObject:taskKey];
    [_preloadBlocks setObject:taskBlock forKey:taskKey];
    [self drainPreloadsLocked];
    pthread_mutex_unlock(&_lock);
}

- (void)finishPreload:(id<NSCopying>)key block:(dispatch_block_t)block deferred:(BOOL)deferred
{
    pthread_mutex_lock(&_lock);
    _preloadRunningCount--;
    if (deferred && [_preloadBlocks objectForKey:key] == nil)
    {
        [_preloadKeys addObject:key];
        [_preloadBlocks setObject:block forKey:key];
    }
    if (_suspendsBackgroundWorkDuringInteraction && _interactionCount != 0 && !LGPlatformUsesConstrainedBackgroundExecution())
    {
        _preloadCoolingDown = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.016 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
            pthread_mutex_lock(&_lock);
            _preloadCoolingDown = NO;
            [self drainPreloadsLocked];
            pthread_mutex_unlock(&_lock);
        });
    }
    else
        [self drainPreloadsLocked];
    pthread_mutex_unlock(&_lock);
}

- (void)drainPreloadsLocked
{
    if (_preloadCoolingDown || (_suspendsBackgroundWorkDuringInteraction && _interactionCount != 0))
        return;
    while (_preloadRunningCount < _preloadWorkerLimit && _preloadKeyOffset < _preloadKeys.count)
    {
        id<NSCopying> key = [_preloadKeys objectAtIndex:_preloadKeyOffset++];
        dispatch_block_t block = [_preloadBlocks objectForKey:key];
        [_preloadBlocks removeObjectForKey:key];
        if (block == nil)
            continue;
        _preloadRunningCount++;
        dispatch_block_t run = ^
        {
            BOOL deferred = _suspendsBackgroundWorkDuringInteraction && LGRuntimeInteractionActiveFast();
            if (!deferred)
            {
                @autoreleasepool
                {
                    block();
                }
            }
            [self finishPreload:key block:block deferred:deferred];
        };
        if (LGPlatformUsesConstrainedBackgroundExecution())
            LGPlatformDispatchAfterCurrentMainRunLoop(run);
        else
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), run);
    }
    if (_preloadKeyOffset == _preloadKeys.count)
    {
        [_preloadKeys removeAllObjects];
        _preloadKeyOffset = 0;
    }
    else if (_preloadKeyOffset >= 128)
    {
        [_preloadKeys removeObjectsInRange:NSMakeRange(0, _preloadKeyOffset)];
        _preloadKeyOffset = 0;
    }
}

- (BOOL)interactionActive
{
    pthread_mutex_lock(&_lock);
    BOOL value = _interactionCount != 0;
    pthread_mutex_unlock(&_lock);
    return value;
}

- (dispatch_queue_t)queueForPriority:(LGRuntimePriority)priority
{
    switch (priority)
    {
        case LGRuntimePriorityInteractive:
            return _interactiveQueue;
        case LGRuntimePriorityUserInitiated:
            return _userQueue;
        case LGRuntimePriorityStorage:
            return _storageQueue;
        case LGRuntimePriorityUtility:
            return _utilityQueue;
        case LGRuntimePriorityMaintenance:
        default:
            return _maintenanceQueue;
    }
}

- (dispatch_queue_t)transferQueue
{
    return _transferQueue;
}

- (void)dispatchPriority:(LGRuntimePriority)priority block:(dispatch_block_t)block
{
    if (block == nil)
        return;

    dispatch_async([self queueForPriority:priority], block);
}

- (void)dispatchPriority:(LGRuntimePriority)priority after:(NSTimeInterval)delay block:(dispatch_block_t)block
{
    if (block == nil)
        return;

    if (delay <= DBL_EPSILON)
    {
        [self dispatchPriority:priority block:block];
        return;
    }

    int64_t nanoseconds = (int64_t)(delay * (NSTimeInterval)NSEC_PER_SEC);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, nanoseconds), [self queueForPriority:priority], block);
}

- (uint64_t)nextToken
{
    uint64_t token = _nextToken++;
    if (_nextToken == 0)
        _nextToken = 1;
    if (token == 0)
        token = _nextToken++;
    return token;
}

- (void)dispatchCoalesced:(NSString *)key priority:(LGRuntimePriority)priority delay:(NSTimeInterval)delay block:(dispatch_block_t)block
{
    if (key.length == 0 || block == nil)
    {
        [self dispatchPriority:priority after:delay block:block];
        return;
    }

    NSString *taskKey = [key copy];
    pthread_mutex_lock(&_lock);
    uint64_t token = [self nextToken];
    [_tokens setObject:[NSNumber numberWithUnsignedLongLong:token] forKey:taskKey];
    pthread_mutex_unlock(&_lock);

    NSTimeInterval safeDelay = delay < 0.0 ? 0.0 : delay;
    int64_t nanoseconds = (int64_t)(safeDelay * (NSTimeInterval)NSEC_PER_SEC);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, nanoseconds), [self queueForPriority:priority], ^
    {
        pthread_mutex_lock(&_lock);
        NSNumber *currentToken = [_tokens objectForKey:taskKey];
        BOOL current = currentToken != nil && [currentToken unsignedLongLongValue] == token;
        if (current)
            [_tokens removeObjectForKey:taskKey];
        pthread_mutex_unlock(&_lock);
        if (current)
            block();
    });
}

- (void)cancelCoalesced:(NSString *)key
{
    if (key.length == 0)
        return;

    pthread_mutex_lock(&_lock);
    [_tokens removeObjectForKey:key];
    pthread_mutex_unlock(&_lock);
}

@end

static LGRuntimeState *LGRuntimeSharedState(void)
{
    static LGRuntimeState *state = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        state = [[LGRuntimeState alloc] init];
    });
    return state;
}

void LGRuntimeConfigureMainThread(void)
{
    if (pthread_main_np() == 0)
        return;
    pthread_t thread = pthread_self();
    thread_act_t port = pthread_mach_thread_np(thread);
    
    int schedulingPolicy = 0;
    struct sched_param schedulingParameters;
    memset(&schedulingParameters, 0, sizeof(schedulingParameters));
    if (pthread_getschedparam(thread, &schedulingPolicy, &schedulingParameters) != 0)
        return;
#if defined(LIGHTGRAM_ARMV6)
    int maximumPriority = MIN(LGRuntimeMainThreadPriority, sched_get_priority_max(schedulingPolicy));
#else
    int maximumPriority = sched_get_priority_max(schedulingPolicy);
#endif
    
    thread_extended_policy_data_t currentPolicy;
    mach_msg_type_number_t count = THREAD_EXTENDED_POLICY_COUNT;
    boolean_t getDefault = FALSE;
    bool policyKnown = thread_policy_get(port, THREAD_EXTENDED_POLICY, (thread_policy_t)&currentPolicy, &count, &getDefault) == KERN_SUCCESS;
    if (schedulingParameters.sched_priority == maximumPriority && policyKnown && !currentPolicy.timeshare)
        return;
    
    int previousPriority = schedulingParameters.sched_priority;
    int previousTimeshare = policyKnown ? (int)currentPolicy.timeshare : -1;
    int priorityResult = 0;
    if (schedulingParameters.sched_priority != maximumPriority)
    {
        schedulingParameters.sched_priority = maximumPriority;
        priorityResult = pthread_setschedparam(thread, schedulingPolicy, &schedulingParameters);
    }
    thread_extended_policy_data_t policy;
    policy.timeshare = FALSE;
    kern_return_t result = thread_policy_set(port, THREAD_EXTENDED_POLICY, (thread_policy_t)&policy, THREAD_EXTENDED_POLICY_COUNT);
    if (LGDiagnosticsEnabled())
        LGPlatformDiagnosticLog(@"MAINPOLICY previousPriority=%d previousTimeshare=%d priority=%d priorityResult=%d fixed=1 result=%d", previousPriority, previousTimeshare, maximumPriority, priorityResult, (int)result);
}

void LGRuntimeBeginInteraction(void)
{
    LGRuntimeConfigureMainThread();
    [LGRuntimeSharedState() beginInteraction];
    LGDatabaseRuntimeInteractionStateChanged();
}

void LGRuntimeEndInteraction(void)
{
    [LGRuntimeSharedState() endInteraction];
    LGDatabaseRuntimeInteractionStateChanged();
}

BOOL LGRuntimeInteractionActive(void)
{
    return [LGRuntimeSharedState() interactionActive];
}

BOOL LGRuntimeSingleCoreDevice(void)
{
    static BOOL singleCore = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        int cpuCount = 1;
        size_t cpuSize = sizeof(cpuCount);
        if (sysctlbyname("hw.ncpu", &cpuCount, &cpuSize, NULL, 0) != 0 || cpuCount < 1)
            cpuCount = 1;
        singleCore = cpuCount == 1;
    });
    return singleCore;
}

BOOL LGRuntimeInteractionActiveFast(void)
{
    return LGRuntimeInteractionFastFlag != 0;
}

static pthread_key_t LGRuntimeLatencyCriticalKey;
static pthread_once_t LGRuntimeLatencyCriticalKeyOnce = PTHREAD_ONCE_INIT;

static void LGRuntimeCreateLatencyCriticalKey(void)
{
    pthread_key_create(&LGRuntimeLatencyCriticalKey, NULL);
}

BOOL LGRuntimeCurrentThreadLatencyCritical(void)
{
    pthread_once(&LGRuntimeLatencyCriticalKeyOnce, LGRuntimeCreateLatencyCriticalKey);
    return pthread_getspecific(LGRuntimeLatencyCriticalKey) != NULL;
}

void LGRuntimePerformLatencyCritical(dispatch_block_t block)
{
    if (block == nil)
        return;
    pthread_once(&LGRuntimeLatencyCriticalKeyOnce, LGRuntimeCreateLatencyCriticalKey);
    uintptr_t depth = (uintptr_t)pthread_getspecific(LGRuntimeLatencyCriticalKey);
    pthread_setspecific(LGRuntimeLatencyCriticalKey, (const void *)(depth + 1));
    block();
    pthread_setspecific(LGRuntimeLatencyCriticalKey, (const void *)depth);
}

@interface LGRuntimeLatencyTask : NSObject
{
@public
    dispatch_block_t _block;
    dispatch_semaphore_t _semaphore;
}

@end

@implementation LGRuntimeLatencyTask

@end

static const uint64_t LGRuntimeLatencyYieldSliceNanoseconds = 4000000ULL;
#if !defined(LIGHTGRAM_ARMV6)
static const mach_msg_timeout_t LGRuntimeLatencyYieldMilliseconds = 4;
static const int LGRuntimeLatencyCriticalPriority = 33;
#endif
static pthread_key_t LGRuntimeLatencyLaneKey;
static pthread_once_t LGRuntimeLatencyLaneKeyOnce = PTHREAD_ONCE_INIT;

typedef struct
{
    uint64_t lastYieldTime;
} LGRuntimeLatencyLaneThreadState;

static void LGRuntimeCreateLatencyLaneKey(void)
{
    pthread_key_create(&LGRuntimeLatencyLaneKey, NULL);
}

static uint64_t LGRuntimeAbsoluteNanoseconds(void)
{
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0)
        mach_timebase_info(&timebase);
    return mach_absolute_time() * timebase.numer / timebase.denom;
}

void LGRuntimeLatencyYield(void)
{
    pthread_once(&LGRuntimeLatencyLaneKeyOnce, LGRuntimeCreateLatencyLaneKey);
    LGRuntimeLatencyLaneThreadState *state = (LGRuntimeLatencyLaneThreadState *)pthread_getspecific(LGRuntimeLatencyLaneKey);
    if (state == NULL)
        return;
    uint64_t now = LGRuntimeAbsoluteNanoseconds();
    if (state->lastYieldTime != 0 && now - state->lastYieldTime < LGRuntimeLatencyYieldSliceNanoseconds)
        return;
    if (state->lastYieldTime != 0)
    {
#if defined(LIGHTGRAM_ARMV6)
        thread_switch(MACH_PORT_NULL, SWITCH_OPTION_NONE, 0);
#else
        if (LGRuntimeInteractionFastFlag != 0)
        {
            struct timespec interval;
            interval.tv_sec = 0;
            interval.tv_nsec = (long)LGRuntimeLatencyYieldMilliseconds * 1000000L;
            nanosleep(&interval, NULL);
        }
        else
            thread_switch(MACH_PORT_NULL, SWITCH_OPTION_DEPRESS, LGRuntimeLatencyYieldMilliseconds);
#endif
    }
    state->lastYieldTime = LGRuntimeAbsoluteNanoseconds();
}

typedef struct
{
    pthread_mutex_t lock;
    pthread_cond_t condition;
    pthread_once_t once;
    void *tasks;
    pthread_t thread;
    bool started;
    const char *name;
} LGRuntimeLatencyLaneState;

static LGRuntimeLatencyLaneState LGRuntimeLatencyLanes[2] = {
    { PTHREAD_MUTEX_INITIALIZER, PTHREAD_COND_INITIALIZER, PTHREAD_ONCE_INIT, nil, NULL, false, "layout" },
    { PTHREAD_MUTEX_INITIALIZER, PTHREAD_COND_INITIALIZER, PTHREAD_ONCE_INIT, nil, NULL, false, "storage" }
};

static void LGRuntimeConfigureLatencyThread(const char *name)
{
    pthread_t thread = pthread_self();
    thread_act_t port = pthread_mach_thread_np(thread);
    int schedulingPolicy = 0;
    struct sched_param parameters;
    memset(&parameters, 0, sizeof(parameters));
    int priorityResult = -1;
    if (pthread_getschedparam(thread, &schedulingPolicy, &parameters) == 0)
    {
#if defined(LIGHTGRAM_ARMV6)
        parameters.sched_priority = MIN(LGRuntimeBackgroundWorkPriority, sched_get_priority_max(schedulingPolicy));
#else
        parameters.sched_priority = MIN(LGRuntimeLatencyCriticalPriority, sched_get_priority_max(schedulingPolicy) - 1);
#endif
        priorityResult = pthread_setschedparam(thread, schedulingPolicy, &parameters);
    }
    thread_extended_policy_data_t policy;
    policy.timeshare = FALSE;
    kern_return_t policyResult = thread_policy_set(port, THREAD_EXTENDED_POLICY, (thread_policy_t)&policy, THREAD_EXTENDED_POLICY_COUNT);
    if (LGDiagnosticsEnabled())
    {
        thread_extended_policy_data_t currentPolicy;
        mach_msg_type_number_t count = THREAD_EXTENDED_POLICY_COUNT;
        boolean_t getDefault = FALSE;
        kern_return_t getResult = thread_policy_get(port, THREAD_EXTENDED_POLICY, (thread_policy_t)&currentPolicy, &count, &getDefault);
        int currentPriority = -1;
        policy_rr_info_data_t fixedInfo;
        count = POLICY_RR_INFO_COUNT;
        if (thread_info(port, THREAD_SCHED_RR_INFO, (thread_info_t)&fixedInfo, &count) == KERN_SUCCESS)
            currentPriority = fixedInfo.base_priority;
        else
        {
            policy_timeshare_info_data_t timeshareInfo;
            count = POLICY_TIMESHARE_INFO_COUNT;
            if (thread_info(port, THREAD_SCHED_TIMESHARE_INFO, (thread_info_t)&timeshareInfo, &count) == KERN_SUCCESS)
                currentPriority = timeshareInfo.base_priority;
        }
        LGPlatformDiagnosticLog(@"LATENCYTHREAD lane=%s priority=%d priorityResult=%d policyResult=%d timeshare=%d", name, currentPriority, priorityResult, (int)policyResult, getResult == KERN_SUCCESS ? (int)currentPolicy.timeshare : -1);
    }
}

static void *LGRuntimeLatencyThreadMain(void *context)
{
    LGRuntimeLatencyLaneState *lane = (LGRuntimeLatencyLaneState *)context;
    pthread_once(&LGRuntimeLatencyCriticalKeyOnce, LGRuntimeCreateLatencyCriticalKey);
    pthread_setspecific(LGRuntimeLatencyCriticalKey, (const void *)1);
    pthread_once(&LGRuntimeLatencyLaneKeyOnce, LGRuntimeCreateLatencyLaneKey);
    LGRuntimeLatencyLaneThreadState *threadState = (LGRuntimeLatencyLaneThreadState *)calloc(1, sizeof(LGRuntimeLatencyLaneThreadState));
    pthread_setspecific(LGRuntimeLatencyLaneKey, threadState);
    @autoreleasepool
    {
        LGRuntimeConfigureLatencyThread(lane->name);
    }
    while (true)
    {
        pthread_mutex_lock(&lane->lock);
        NSMutableArray *tasks = (__bridge NSMutableArray *)lane->tasks;
        while (tasks.count == 0)
            pthread_cond_wait(&lane->condition, &lane->lock);
        LGRuntimeLatencyTask *task = [tasks objectAtIndex:0];
        [tasks removeObjectAtIndex:0];
        pthread_mutex_unlock(&lane->lock);
        
        if (threadState != NULL)
            threadState->lastYieldTime = 0;
        @autoreleasepool
        {
            task->_block();
        }
        dispatch_semaphore_signal(task->_semaphore);
    }
    return NULL;
}

static void LGRuntimeStartLatencyLane(LGRuntimeLatencyLaneState *lane)
{
    lane->tasks = (__bridge_retained void *)[[NSMutableArray alloc] init];
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_setdetachstate(&attributes, PTHREAD_CREATE_DETACHED);
    pthread_attr_setstacksize(&attributes, 1024 * 1024);
    lane->started = pthread_create(&lane->thread, &attributes, LGRuntimeLatencyThreadMain, lane) == 0;
    pthread_attr_destroy(&attributes);
}

static void LGRuntimeStartLayoutLatencyLane(void)
{
    LGRuntimeStartLatencyLane(&LGRuntimeLatencyLanes[LGRuntimeLatencyLaneLayout]);
}

static void LGRuntimeStartStorageLatencyLane(void)
{
    LGRuntimeStartLatencyLane(&LGRuntimeLatencyLanes[LGRuntimeLatencyLaneStorage]);
}

void LGRuntimePerformOnLatencyLane(LGRuntimeLatencyLane laneIndex, dispatch_block_t block)
{
    if (block == nil)
        return;
    LGRuntimeLatencyLaneState *lane = &LGRuntimeLatencyLanes[laneIndex == LGRuntimeLatencyLaneStorage ? LGRuntimeLatencyLaneStorage : LGRuntimeLatencyLaneLayout];
    pthread_once(&lane->once, laneIndex == LGRuntimeLatencyLaneStorage ? LGRuntimeStartStorageLatencyLane : LGRuntimeStartLayoutLatencyLane);
    if (!lane->started || pthread_main_np() != 0 || pthread_equal(pthread_self(), lane->thread))
    {
        LGRuntimePerformLatencyCritical(block);
        return;
    }
    
    LGRuntimeLatencyTask *task = [[LGRuntimeLatencyTask alloc] init];
    task->_block = [block copy];
    task->_semaphore = dispatch_semaphore_create(0);
    
    pthread_mutex_lock(&lane->lock);
    [(__bridge NSMutableArray *)lane->tasks addObject:task];
    pthread_cond_signal(&lane->condition);
    pthread_mutex_unlock(&lane->lock);
    
    dispatch_semaphore_wait(task->_semaphore, DISPATCH_TIME_FOREVER);
#if !OS_OBJECT_USE_OBJC
    dispatch_release(task->_semaphore);
#endif
    task->_semaphore = NULL;
}

dispatch_block_t LGRuntimeLatencyCriticalBlock(dispatch_block_t block)
{
    if (block == nil)
        return nil;
    dispatch_block_t copiedBlock = [block copy];
    return [^
    {
        LGRuntimePerformLatencyCritical(copiedBlock);
    } copy];
}

static const uint64_t LGRuntimeCooperationSliceNanoseconds = 2000000ULL;
static const long LGRuntimeCooperationSleepNanoseconds = 2000000L;
static pthread_key_t LGRuntimeCooperationKey;
static pthread_once_t LGRuntimeCooperationKeyOnce = PTHREAD_ONCE_INIT;

static void LGRuntimeCreateCooperationKey(void)
{
    pthread_key_create(&LGRuntimeCooperationKey, free);
}

void LGRuntimeCooperateWithInteraction(void)
{
    if (LGRuntimeCurrentThreadLatencyCritical())
    {
        LGRuntimeLatencyYield();
        return;
    }
    if (LGRuntimeInteractionFastFlag == 0)
        return;
    if (pthread_main_np() != 0)
        return;
    pthread_once(&LGRuntimeCooperationKeyOnce, LGRuntimeCreateCooperationKey);
    uint64_t *sliceStart = (uint64_t *)pthread_getspecific(LGRuntimeCooperationKey);
    if (sliceStart == NULL)
    {
        sliceStart = (uint64_t *)malloc(sizeof(uint64_t));
        if (sliceStart == NULL)
            return;
        *sliceStart = LGRuntimeAbsoluteNanoseconds();
        pthread_setspecific(LGRuntimeCooperationKey, sliceStart);
        return;
    }
    if (LGRuntimeAbsoluteNanoseconds() - *sliceStart < LGRuntimeCooperationSliceNanoseconds)
        return;
    struct timespec interval;
    interval.tv_sec = 0;
    interval.tv_nsec = LGRuntimeCooperationSleepNanoseconds;
    nanosleep(&interval, NULL);
    *sliceStart = LGRuntimeAbsoluteNanoseconds();
}

dispatch_queue_t LGRuntimeTransferQueue(void)
{
    return [LGRuntimeSharedState() transferQueue];
}


dispatch_queue_t LGRuntimeQueueForPriority(LGRuntimePriority priority)
{
    return [LGRuntimeSharedState() queueForPriority:priority];
}

void LGRuntimeDispatch(LGRuntimePriority priority, dispatch_block_t block)
{
    [LGRuntimeSharedState() dispatchPriority:priority block:block];
}

void LGRuntimeDispatchPreload(id<NSCopying> key, dispatch_block_t block)
{
    [LGRuntimeSharedState() enqueuePreload:key block:block];
}

void LGRuntimeDispatchAfter(LGRuntimePriority priority, NSTimeInterval delay, dispatch_block_t block)
{
    [LGRuntimeSharedState() dispatchPriority:priority after:delay block:block];
}

void LGRuntimeDispatchCoalesced(NSString *key, LGRuntimePriority priority, NSTimeInterval delay, dispatch_block_t block)
{
    [LGRuntimeSharedState() dispatchCoalesced:key priority:priority delay:delay block:block];
}

void LGRuntimeCancelCoalesced(NSString *key)
{
    [LGRuntimeSharedState() cancelCoalesced:key];
}

void LGRuntimeDispatchAfterStartupPhase(LGRuntimePriority priority, dispatch_block_t block)
{
    [[LGRuntimeSharedState() startupGate] dispatchPriority:priority block:block];
}

void LGRuntimeCompleteStartupPhase(NSString *__unused reason)
{
    if (LGRuntimeStartupPhaseCompletedFlag != 0)
        return;

    [[LGRuntimeSharedState() startupGate] complete];
}

void LGRuntimeExtendStartupPhase(void)
{
    if (LGRuntimeStartupPhaseCompletedFlag != 0)
        return;

    [[LGRuntimeSharedState() startupGate] extend];
}

BOOL LGRuntimeStartupPhaseCompleted(void)
{
    return LGRuntimeStartupPhaseCompletedFlag != 0;
}

static void LGRuntimeScheduleStartupSyncCompletion(void)
{
    if (LGRuntimeStartupPhaseCompletedFlag != 0 || OSAtomicAdd32Barrier(0, &LGRuntimeStartupSyncFinishedFlag) == 0 || OSAtomicAdd32Barrier(0, &LGRuntimeSyncActivityCount) != 0)
        return;

    int32_t generation = OSAtomicIncrement32Barrier(&LGRuntimeStartupSyncGeneration);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LGRuntimeStartupSyncQuietInterval * (NSTimeInterval)NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        if (generation == OSAtomicAdd32Barrier(0, &LGRuntimeStartupSyncGeneration) && OSAtomicAdd32Barrier(0, &LGRuntimeSyncActivityCount) == 0)
            LGRuntimeCompleteStartupPhase(@"sync");
    });
}

void LGRuntimeCompleteStartupSync(void)
{
    OSAtomicCompareAndSwap32Barrier(0, 1, &LGRuntimeStartupSyncFinishedFlag);
    LGRuntimeScheduleStartupSyncCompletion();
}

@implementation LGRuntimeSyncActivity
{
    volatile int32_t _ended;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        OSAtomicIncrement32Barrier(&LGRuntimeSyncActivityCount);
        OSAtomicIncrement32Barrier(&LGRuntimeStartupSyncGeneration);
    }
    return self;
}

- (void)dealloc
{
    [self end];
}

- (void)end
{
    if (!OSAtomicCompareAndSwap32Barrier(0, 1, &_ended))
        return;
    if (OSAtomicDecrement32Barrier(&LGRuntimeSyncActivityCount) == 0)
        LGRuntimeScheduleStartupSyncCompletion();
}

@end

void LGRuntimeDispatchAfterFirstFrame(LGRuntimePriority priority, dispatch_block_t block)
{
    [[LGRuntimeSharedState() firstFrameGate] dispatchPriority:priority block:block];
}

void LGRuntimeCompleteFirstFrame(void)
{
    if (LGRuntimeFirstFrameCompletedFlag != 0)
        return;

    [[LGRuntimeSharedState() firstFrameGate] complete];
}

BOOL LGRuntimeFirstFrameCompleted(void)
{
    return LGRuntimeFirstFrameCompletedFlag != 0;
}
