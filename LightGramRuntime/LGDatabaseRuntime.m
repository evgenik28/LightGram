#import "LGDatabaseRuntime.h"
#import "LGRuntime.h"
#import "../LightGramPlatform/LGPlatformDispatch.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include "../thirdparty/sqlcipher/sqlite3.h"
#include <pthread.h>
#include <stdint.h>
#include <libkern/OSAtomic.h>
#include <sched.h>

typedef enum
{
    LGDatabaseRuntimeBoostNone = 0,
    LGDatabaseRuntimeBoostWaiter = 1,
    LGDatabaseRuntimeBoostMainWaiter = 2
} LGDatabaseRuntimeBoost;

#if defined(LIGHTGRAM_ARMV6)
static const int LGDatabaseRuntimeWaiterPriority = LGRuntimeBackgroundWaiterPriority;
#else
static const int LGDatabaseRuntimeWaiterPriority = 33;
#endif

static BOOL LGDatabaseRuntimeIsConstrained(void)
{
    return LGPlatformUsesConstrainedBackgroundExecution();
}

static pthread_key_t LGDatabaseRuntimeSynchronousKey;
static pthread_once_t LGDatabaseRuntimeSynchronousKeyOnce = PTHREAD_ONCE_INIT;

static void LGDatabaseRuntimeCreateSynchronousKey(void)
{
    pthread_key_create(&LGDatabaseRuntimeSynchronousKey, NULL);
}

static void LGDatabaseRuntimeSetSynchronous(BOOL synchronous)
{
    pthread_once(&LGDatabaseRuntimeSynchronousKeyOnce, LGDatabaseRuntimeCreateSynchronousKey);
    pthread_setspecific(LGDatabaseRuntimeSynchronousKey, synchronous ? (void *)(uintptr_t)1 : NULL);
}

static BOOL LGDatabaseRuntimeCurrentTaskIsSynchronous(void)
{
    pthread_once(&LGDatabaseRuntimeSynchronousKeyOnce, LGDatabaseRuntimeCreateSynchronousKey);
    return pthread_getspecific(LGDatabaseRuntimeSynchronousKey) != NULL;
}

@interface LGDatabaseRuntimeTask : NSObject
{
@public
    dispatch_queue_t _queue;
    dispatch_block_t _block;
    dispatch_semaphore_t _semaphore;
    BOOL _synchronous;
    BOOL _mainThreadWaiter;
    BOOL _startupCritical;
    BOOL _background;
    BOOL _interactive;
    CFAbsoluteTime _submittedAt;
}
- (instancetype)initWithQueue:(dispatch_queue_t)queue synchronous:(BOOL)synchronous mainThreadWaiter:(BOOL)mainThreadWaiter startupCritical:(BOOL)startupCritical block:(dispatch_block_t)block semaphore:(dispatch_semaphore_t)semaphore;
@end

@implementation LGDatabaseRuntimeTask

- (instancetype)initWithQueue:(dispatch_queue_t)queue synchronous:(BOOL)synchronous mainThreadWaiter:(BOOL)mainThreadWaiter startupCritical:(BOOL)startupCritical block:(dispatch_block_t)block semaphore:(dispatch_semaphore_t)semaphore
{
    self = [super init];
    if (self != nil)
    {
        _queue = queue;
        _block = [block copy];
        _semaphore = semaphore;
        _synchronous = synchronous;
        _mainThreadWaiter = mainThreadWaiter;
        _startupCritical = startupCritical;
        _submittedAt = CACurrentMediaTime();
    }
    return self;
}

@end

@interface LGDatabaseRuntimeState : NSObject
{
    pthread_mutex_t _lock;
    NSMutableArray *_mainThreadTasks;
    NSMutableArray *_synchronousTasks;
    NSMutableArray *_startupCriticalTasks;
    NSMutableArray *_interactiveTasks;
    NSMutableArray *_storageTasks;
    NSMutableArray *_backgroundTasks;
    NSUInteger _startupCriticalCount;
    BOOL _running;
    BOOL _storageWakeScheduled;
    NSUInteger _priorityTaskBurst;
    CFAbsoluteTime _runningSubmittedAt;
    volatile int32_t _pendingPriorityTaskCount;
    volatile int32_t _pendingStorageTaskCount;
    pthread_t _runningThread;
    LGDatabaseRuntimeBoost _runningBoost;
    BOOL _runningThreadSchedulingSaved;
    int _runningThreadPolicy;
    struct sched_param _runningThreadParameters;
}
- (void)dispatchQueue:(dispatch_queue_t)queue synchronous:(BOOL)synchronous block:(dispatch_block_t)block;
- (void)dispatchContinuationOnQueue:(dispatch_queue_t)queue block:(dispatch_block_t)block;
- (void)dispatchBackgroundOnQueue:(dispatch_queue_t)queue block:(dispatch_block_t)block;
- (void)dispatchInteractiveOnQueue:(dispatch_queue_t)queue block:(dispatch_block_t)block;
- (BOOL)priorityWorkPending;
- (BOOL)foregroundWorkPending;
- (void)beginStartupCritical;
- (void)endStartupCritical;
- (void)interactionStateChanged;
@end

@implementation LGDatabaseRuntimeState

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_lock, NULL);
        _mainThreadTasks = [[NSMutableArray alloc] init];
        _synchronousTasks = [[NSMutableArray alloc] init];
        _startupCriticalTasks = [[NSMutableArray alloc] init];
        _interactiveTasks = [[NSMutableArray alloc] init];
        _storageTasks = [[NSMutableArray alloc] init];
        _backgroundTasks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (LGDatabaseRuntimeTask *)takeFirstTaskFromQueue:(NSMutableArray *)queue
{
    if (queue.count == 0)
        return nil;

    LGDatabaseRuntimeTask *task = [queue objectAtIndex:0];
    [queue removeObjectAtIndex:0];
    if (queue == _storageTasks)
        OSAtomicDecrement32Barrier(&_pendingStorageTaskCount);
    return task;
}

- (LGDatabaseRuntimeTask *)nextTaskLocked
{
    LGDatabaseRuntimeTask *task = [self takeFirstTaskFromQueue:_mainThreadTasks];
    if (task == nil && _priorityTaskBurst >= 8 && _startupCriticalCount == 0 && _startupCriticalTasks.count == 0 && _storageTasks.count != 0)
    {
        LGDatabaseRuntimeTask *oldest = _storageTasks[0];
        if (CACurrentMediaTime() - oldest->_submittedAt >= 2.0)
        {
            _priorityTaskBurst = 0;
            return [self takeFirstTaskFromQueue:_storageTasks];
        }
    }
    if (task == nil)
        task = [self takeFirstTaskFromQueue:_synchronousTasks];
    if (task == nil)
        task = [self takeFirstTaskFromQueue:_interactiveTasks];
    if (task == nil)
        task = [self takeFirstTaskFromQueue:_startupCriticalTasks];
    if (task != nil)
    {
        OSAtomicDecrement32Barrier(&_pendingPriorityTaskCount);
        _priorityTaskBurst++;
        return task;
    }

    if (LGRuntimeInteractionActiveFast() && _storageTasks.count != 0)
    {
        LGDatabaseRuntimeTask *oldest = _storageTasks[0];
        CFAbsoluteTime remaining = 1.0 - (CACurrentMediaTime() - oldest->_submittedAt);
        if (remaining > 0.0)
        {
            if (!_storageWakeScheduled)
            {
                _storageWakeScheduled = YES;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remaining * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^
                {
                    pthread_mutex_lock(&_lock);
                    _storageWakeScheduled = NO;
                    [self scheduleDrainLocked];
                    pthread_mutex_unlock(&_lock);
                });
            }
            return nil;
        }
    }
    _priorityTaskBurst = 0;
    task = [self takeFirstTaskFromQueue:_storageTasks];
    if (task != nil || LGRuntimeInteractionActiveFast())
        return task;
    return [self takeFirstTaskFromQueue:_backgroundTasks];
}

- (LGDatabaseRuntimeBoost)boostForTask:(LGDatabaseRuntimeTask *)task
{
    if (task->_mainThreadWaiter)
        return LGDatabaseRuntimeBoostMainWaiter;
    if (task->_synchronous || task->_startupCritical || task->_interactive)
        return LGDatabaseRuntimeBoostWaiter;
    return LGDatabaseRuntimeBoostNone;
}

- (LGDatabaseRuntimeBoost)queuedWaiterBoostLocked
{
    if (_mainThreadTasks.count != 0)
        return LGDatabaseRuntimeBoostMainWaiter;
    if (_synchronousTasks.count != 0 || _startupCriticalTasks.count != 0 || _interactiveTasks.count != 0)
        return LGDatabaseRuntimeBoostWaiter;
    return LGDatabaseRuntimeBoostNone;
}

- (void)boostRunningThreadLocked:(LGDatabaseRuntimeBoost)boost
{
    if (_runningThread == NULL || boost <= _runningBoost)
        return;
    if (!_runningThreadSchedulingSaved)
    {
        if (pthread_getschedparam(_runningThread, &_runningThreadPolicy, &_runningThreadParameters) != 0)
            return;
        _runningThreadSchedulingSaved = YES;
    }
#if defined(LIGHTGRAM_ARMV6)
    int mainWaiterPriority = MIN(LGRuntimeMainThreadPriority, sched_get_priority_max(_runningThreadPolicy));
#else
    int mainWaiterPriority = sched_get_priority_max(_runningThreadPolicy) - 1;
#endif
    int priority = boost == LGDatabaseRuntimeBoostMainWaiter ? mainWaiterPriority : LGDatabaseRuntimeWaiterPriority;
    _runningBoost = boost;
    if (priority <= _runningThreadParameters.sched_priority)
        return;
    struct sched_param parameters = _runningThreadParameters;
    parameters.sched_priority = priority;
    pthread_setschedparam(_runningThread, _runningThreadPolicy, &parameters);
}

- (void)beginRunningTaskLocked:(LGDatabaseRuntimeTask *)task
{
    _runningThread = pthread_self();
    _runningBoost = LGDatabaseRuntimeBoostNone;
    _runningThreadSchedulingSaved = NO;
    LGDatabaseRuntimeBoost boost = [self boostForTask:task];
    LGDatabaseRuntimeBoost queuedBoost = [self queuedWaiterBoostLocked];
    [self boostRunningThreadLocked:queuedBoost > boost ? queuedBoost : boost];
}

- (void)endRunningTaskLocked
{
    if (_runningThreadSchedulingSaved && _runningBoost != LGDatabaseRuntimeBoostNone)
        pthread_setschedparam(_runningThread, _runningThreadPolicy, &_runningThreadParameters);
    _runningThread = NULL;
    _runningBoost = LGDatabaseRuntimeBoostNone;
    _runningThreadSchedulingSaved = NO;
}

- (void)scheduleDrainLocked
{
    if (_running)
        return;

    LGDatabaseRuntimeTask *task = [self nextTaskLocked];
    if (task == nil)
        return;

    _running = YES;
    _runningSubmittedAt = task->_submittedAt;

    dispatch_async(task->_queue, ^
    {
        pthread_mutex_lock(&_lock);
        [self beginRunningTaskLocked:task];
        pthread_mutex_unlock(&_lock);

        LGDatabaseRuntimeSetSynchronous(task->_synchronous || task->_startupCritical);

        @autoreleasepool
        {
            task->_block();
        }


        LGDatabaseRuntimeSetSynchronous(NO);

        if (task->_semaphore != NULL)
            dispatch_semaphore_signal(task->_semaphore);

        pthread_mutex_lock(&_lock);
        [self endRunningTaskLocked];
        _running = NO;
        if (_mainThreadTasks.count != 0 || _synchronousTasks.count != 0 || _startupCriticalTasks.count != 0 || _interactiveTasks.count != 0)
        {
            [self scheduleDrainLocked];
        }
        else
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.002 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^
            {
                pthread_mutex_lock(&_lock);
                [self scheduleDrainLocked];
                pthread_mutex_unlock(&_lock);
            });
        }
        pthread_mutex_unlock(&_lock);
    });
}

- (void)enqueueTaskLocked:(LGDatabaseRuntimeTask *)task
{
    if (task->_mainThreadWaiter)
        [_mainThreadTasks addObject:task];
    else if (task->_synchronous)
        [_synchronousTasks addObject:task];
    else if (task->_interactive)
        [_interactiveTasks addObject:task];
    else if (task->_startupCritical)
        [_startupCriticalTasks addObject:task];
    else if (task->_background)
        [_backgroundTasks addObject:task];
    else
    {
        [_storageTasks addObject:task];
        OSAtomicIncrement32Barrier(&_pendingStorageTaskCount);
    }

    if (task->_mainThreadWaiter || task->_synchronous || task->_startupCritical || task->_interactive)
        OSAtomicIncrement32Barrier(&_pendingPriorityTaskCount);

    [self boostRunningThreadLocked:[self boostForTask:task]];
    [self scheduleDrainLocked];
}

- (void)dispatchQueue:(dispatch_queue_t)queue synchronous:(BOOL)synchronous block:(dispatch_block_t)block
{
    if (queue == NULL || block == nil)
        return;

    BOOL mainThreadWaiter = synchronous && [NSThread isMainThread];
    dispatch_semaphore_t semaphore = synchronous ? dispatch_semaphore_create(0) : NULL;
    pthread_mutex_lock(&_lock);
    BOOL startupCritical = _startupCriticalCount != 0;
    pthread_mutex_unlock(&_lock);
    LGDatabaseRuntimeTask *task = [[LGDatabaseRuntimeTask alloc] initWithQueue:queue synchronous:synchronous mainThreadWaiter:mainThreadWaiter startupCritical:startupCritical block:block semaphore:semaphore];

    if (synchronous)
    {
        pthread_mutex_lock(&_lock);
        [self enqueueTaskLocked:task];
        pthread_mutex_unlock(&_lock);

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
#if !OS_OBJECT_USE_OBJC
        dispatch_release(semaphore);
#endif
    }
    else
    {
        pthread_mutex_lock(&_lock);
        [self enqueueTaskLocked:task];
        pthread_mutex_unlock(&_lock);
    }
}

- (void)dispatchContinuationOnQueue:(dispatch_queue_t)queue block:(dispatch_block_t)block
{
    if (queue == NULL || block == nil)
        return;

    LGDatabaseRuntimeTask *task = [[LGDatabaseRuntimeTask alloc] initWithQueue:queue synchronous:NO mainThreadWaiter:NO startupCritical:NO block:block semaphore:NULL];
    pthread_mutex_lock(&_lock);
    if (_runningSubmittedAt > 0.0)
        task->_submittedAt = MIN(task->_submittedAt, _runningSubmittedAt);
    [_storageTasks insertObject:task atIndex:0];
    OSAtomicIncrement32Barrier(&_pendingStorageTaskCount);
    [self scheduleDrainLocked];
    pthread_mutex_unlock(&_lock);
}

- (void)dispatchBackgroundOnQueue:(dispatch_queue_t)queue block:(dispatch_block_t)block
{
    if (queue == NULL || block == nil)
        return;

    LGDatabaseRuntimeTask *task = [[LGDatabaseRuntimeTask alloc] initWithQueue:queue synchronous:NO mainThreadWaiter:NO startupCritical:NO block:block semaphore:NULL];
    task->_background = YES;
    pthread_mutex_lock(&_lock);
    [self enqueueTaskLocked:task];
    pthread_mutex_unlock(&_lock);
}

- (void)dispatchInteractiveOnQueue:(dispatch_queue_t)queue block:(dispatch_block_t)block
{
    if (queue == NULL || block == nil)
        return;

    LGDatabaseRuntimeTask *task = [[LGDatabaseRuntimeTask alloc] initWithQueue:queue synchronous:NO mainThreadWaiter:NO startupCritical:NO block:block semaphore:NULL];
    task->_interactive = YES;
    pthread_mutex_lock(&_lock);
    [self enqueueTaskLocked:task];
    pthread_mutex_unlock(&_lock);
}

- (BOOL)priorityWorkPending
{
    return _pendingPriorityTaskCount > 0;
}

- (BOOL)foregroundWorkPending
{
    return _pendingPriorityTaskCount > 0 || _pendingStorageTaskCount > 0;
}

- (void)beginStartupCritical
{
    pthread_mutex_lock(&_lock);
    _startupCriticalCount++;
    pthread_mutex_unlock(&_lock);
}

- (void)endStartupCritical
{
    pthread_mutex_lock(&_lock);
    if (_startupCriticalCount != 0)
        _startupCriticalCount--;
    [self scheduleDrainLocked];
    pthread_mutex_unlock(&_lock);
}

- (void)interactionStateChanged
{
    pthread_mutex_lock(&_lock);
    [self scheduleDrainLocked];
    pthread_mutex_unlock(&_lock);
}

@end

@interface LGDatabaseMainPriorityTask : NSObject
{
@public
    dispatch_queue_t _queue;
    dispatch_block_t _block;
    dispatch_semaphore_t _semaphore;
    BOOL _mainAsync;
    BOOL _mainWaiter;
}
@end

@implementation LGDatabaseMainPriorityTask
@end

static const CFTimeInterval LGDatabaseMainPriorityDrainBudget = 0.008;

@interface LGDatabaseMainPriorityState : NSObject
{
    pthread_mutex_t _lock;
    NSMutableArray *_tasks;
    BOOL _running;
    volatile int32_t _pendingMainWaiterCount;
}
- (void)dispatchQueue:(dispatch_queue_t)queue synchronous:(BOOL)synchronous block:(dispatch_block_t)block;
- (void)dispatchContinuationOnQueue:(dispatch_queue_t)queue block:(dispatch_block_t)block;
- (BOOL)priorityWorkPending;
@end

@implementation LGDatabaseMainPriorityState

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_lock, NULL);
        _tasks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)drainOnQueue:(dispatch_queue_t)queue
{
    CFAbsoluteTime drainStart = CACurrentMediaTime();
    for (;;)
    {
        pthread_mutex_lock(&_lock);
        if (_tasks.count == 0)
        {
            _running = NO;
            pthread_mutex_unlock(&_lock);
            return;
        }

        LGDatabaseMainPriorityTask *task = [_tasks objectAtIndex:0];
        if (task->_queue != queue || (!task->_mainWaiter && CACurrentMediaTime() - drainStart >= LGDatabaseMainPriorityDrainBudget))
        {
            dispatch_queue_t nextQueue = task->_queue;
            pthread_mutex_unlock(&_lock);
            dispatch_async(nextQueue, ^
            {
                [self drainOnQueue:nextQueue];
            });
            return;
        }

        [_tasks removeObjectAtIndex:0];
        if (task->_mainWaiter)
            OSAtomicDecrement32Barrier(&_pendingMainWaiterCount);
        pthread_mutex_unlock(&_lock);

        @autoreleasepool
        {
            task->_block();
        }

        if (task->_semaphore != NULL)
            dispatch_semaphore_signal(task->_semaphore);
    }
}

- (void)dispatchQueue:(dispatch_queue_t)queue synchronous:(BOOL)synchronous block:(dispatch_block_t)block
{
    if (queue == NULL || block == nil)
        return;

    BOOL mainThread = [NSThread isMainThread];
    LGDatabaseMainPriorityTask *task = [[LGDatabaseMainPriorityTask alloc] init];
    task->_queue = queue;
    task->_block = [block copy];
    task->_semaphore = synchronous ? dispatch_semaphore_create(0) : NULL;
    task->_mainAsync = mainThread && !synchronous;
    task->_mainWaiter = mainThread && synchronous;
    dispatch_semaphore_t semaphore = task->_semaphore;

    BOOL startDrain = NO;
    pthread_mutex_lock(&_lock);
    if (task->_mainWaiter)
    {
        NSUInteger insertIndex = 0;
        for (NSUInteger index = _tasks.count; index > 0; index--)
        {
            if (((LGDatabaseMainPriorityTask *)[_tasks objectAtIndex:index - 1])->_mainAsync)
            {
                insertIndex = index;
                break;
            }
        }
        [_tasks insertObject:task atIndex:insertIndex];
        OSAtomicIncrement32Barrier(&_pendingMainWaiterCount);
    }
    else
    {
        [_tasks addObject:task];
    }
    if (!_running)
    {
        _running = YES;
        startDrain = YES;
    }
    pthread_mutex_unlock(&_lock);
    task = nil;

    if (startDrain)
    {
        dispatch_async(queue, ^
        {
            [self drainOnQueue:queue];
        });
    }

    if (semaphore != NULL)
    {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
#if !OS_OBJECT_USE_OBJC
        dispatch_release(semaphore);
#endif
    }
}

- (void)dispatchContinuationOnQueue:(dispatch_queue_t)queue block:(dispatch_block_t)block
{
    if (queue == NULL || block == nil)
        return;

    LGDatabaseMainPriorityTask *task = [[LGDatabaseMainPriorityTask alloc] init];
    task->_queue = queue;
    task->_block = [block copy];

    BOOL startDrain = NO;
    pthread_mutex_lock(&_lock);
    NSUInteger insertIndex = 0;
    NSUInteger count = _tasks.count;
    while (insertIndex < count)
    {
        LGDatabaseMainPriorityTask *queuedTask = [_tasks objectAtIndex:insertIndex];
        if (!queuedTask->_mainWaiter && !queuedTask->_mainAsync)
            break;
        insertIndex++;
    }
    [_tasks insertObject:task atIndex:insertIndex];
    if (!_running)
    {
        _running = YES;
        startDrain = YES;
    }
    pthread_mutex_unlock(&_lock);

    if (startDrain)
    {
        dispatch_async(queue, ^
        {
            [self drainOnQueue:queue];
        });
    }
}

- (BOOL)priorityWorkPending
{
    return _pendingMainWaiterCount > 0;
}

@end

static BOOL LGDatabaseRuntimeUsesMainPriority(void)
{
    static BOOL value = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        value = !LGDatabaseRuntimeIsConstrained() && LGRuntimeSingleCoreDevice();
    });
    return value;
}

static LGDatabaseMainPriorityState *LGDatabaseRuntimeMainPriorityState(void)
{
    static LGDatabaseMainPriorityState *state = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        state = [[LGDatabaseMainPriorityState alloc] init];
    });
    return state;
}

static LGDatabaseRuntimeState *LGDatabaseRuntimeSharedState(void)
{
    static LGDatabaseRuntimeState *state = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        state = [[LGDatabaseRuntimeState alloc] init];
    });
    return state;
}

void LGDatabaseRuntimeDispatch(dispatch_queue_t queue, BOOL synchronous, dispatch_block_t block)
{
    if (block == nil)
        return;

    if (!LGDatabaseRuntimeIsConstrained())
    {
        if (LGDatabaseRuntimeUsesMainPriority())
            [LGDatabaseRuntimeMainPriorityState() dispatchQueue:queue synchronous:synchronous block:block];
        else if (synchronous)
            dispatch_sync(queue, block);
        else
            dispatch_async(queue, block);
        return;
    }

    [LGDatabaseRuntimeSharedState() dispatchQueue:queue synchronous:synchronous block:block];
}

BOOL LGDatabaseRuntimePriorityWorkPending(void)
{
    if (LGDatabaseRuntimeIsConstrained())
        return [LGDatabaseRuntimeSharedState() priorityWorkPending];
    if (LGDatabaseRuntimeUsesMainPriority())
        return [LGDatabaseRuntimeMainPriorityState() priorityWorkPending];
    return NO;
}

BOOL LGDatabaseRuntimeForegroundWorkPending(void)
{
    if (LGDatabaseRuntimeIsConstrained())
        return [LGDatabaseRuntimeSharedState() foregroundWorkPending];
    if (LGDatabaseRuntimeUsesMainPriority())
        return [LGDatabaseRuntimeMainPriorityState() priorityWorkPending];
    return NO;
}

void LGDatabaseRuntimeDispatchContinuation(dispatch_queue_t queue, dispatch_block_t block)
{
    if (block == nil)
        return;

    if (LGDatabaseRuntimeIsConstrained())
        [LGDatabaseRuntimeSharedState() dispatchContinuationOnQueue:queue block:block];
    else if (LGDatabaseRuntimeUsesMainPriority())
        [LGDatabaseRuntimeMainPriorityState() dispatchContinuationOnQueue:queue block:block];
    else
        dispatch_async(queue, block);
}

void LGDatabaseRuntimeDispatchInteractive(dispatch_queue_t queue, dispatch_block_t block)
{
    if (block == nil)
        return;

    if (LGDatabaseRuntimeIsConstrained())
        [LGDatabaseRuntimeSharedState() dispatchInteractiveOnQueue:queue block:block];
    else
        LGDatabaseRuntimeDispatch(queue, NO, block);
}

void LGDatabaseRuntimeDispatchBackground(dispatch_queue_t queue, dispatch_block_t block)
{
    if (block == nil)
        return;

    if (LGDatabaseRuntimeIsConstrained())
        [LGDatabaseRuntimeSharedState() dispatchBackgroundOnQueue:queue block:block];
    else
        LGDatabaseRuntimeDispatch(queue, NO, block);
}

void LGDatabaseRuntimeBeginStartupCritical(void)
{
    if (!LGDatabaseRuntimeIsConstrained())
        return;
    [LGDatabaseRuntimeSharedState() beginStartupCritical];
}

void LGDatabaseRuntimeEndStartupCritical(void)
{
    if (!LGDatabaseRuntimeIsConstrained())
        return;
    [LGDatabaseRuntimeSharedState() endStartupCritical];
}

void LGDatabaseRuntimeInteractionStateChanged(void)
{
    if (!LGDatabaseRuntimeIsConstrained())
        return;

    [LGDatabaseRuntimeSharedState() interactionStateChanged];
}

void LGDatabaseRuntimeCooperateDuringInteraction(void)
{
    if (!LGDatabaseRuntimeIsConstrained())
        return;
    if (!LGRuntimeInteractionActiveFast())
        return;
    if (LGDatabaseRuntimeCurrentTaskIsSynchronous() || [LGDatabaseRuntimeSharedState() priorityWorkPending])
        return;

    LGRuntimeCooperateWithInteraction();
}

static int LGDatabaseRuntimeProgressHandler(void *context)
{
    (void)context;

    if (!LGDatabaseRuntimeIsConstrained())
        return 0;

    LGRuntimeLatencyYield();

    if (!LGRuntimeInteractionActiveFast())
        return 0;

    if (!LGDatabaseRuntimeCurrentTaskIsSynchronous() && ![LGDatabaseRuntimeSharedState() priorityWorkPending])
        LGRuntimeCooperateWithInteraction();

    return 0;
}

void LGDatabaseRuntimeConfigureSQLite(struct sqlite3 *database)
{
    if (database == NULL || !LGDatabaseRuntimeIsConstrained())
        return;

    sqlite3_progress_handler(database, 512, LGDatabaseRuntimeProgressHandler, NULL);
}
