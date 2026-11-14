#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

typedef enum {
    LGRuntimePriorityInteractive = 0,
    LGRuntimePriorityUserInitiated = 1,
    LGRuntimePriorityStorage = 2,
    LGRuntimePriorityUtility = 3,
    LGRuntimePriorityMaintenance = 4
} LGRuntimePriority;

enum
{
    LGRuntimeMainThreadPriority = 31,
    LGRuntimeBackgroundWorkPriority = 18,
    LGRuntimeBackgroundWaiterPriority = 19
};

@interface LGRuntimeSyncActivity : NSObject

- (void)end;

@end

typedef enum {
    LGRuntimeLatencyLaneLayout = 0,
    LGRuntimeLatencyLaneStorage = 1
} LGRuntimeLatencyLane;

#ifdef __cplusplus
extern "C" {
#endif

void LGRuntimeConfigureMainThread(void);
void LGRuntimeBeginInteraction(void);
void LGRuntimeEndInteraction(void);
BOOL LGRuntimeInteractionActive(void);
BOOL LGRuntimeInteractionActiveFast(void);
BOOL LGRuntimeSingleCoreDevice(void);
void LGRuntimeCooperateWithInteraction(void);
void LGRuntimePerformLatencyCritical(dispatch_block_t block);
dispatch_block_t LGRuntimeLatencyCriticalBlock(dispatch_block_t block);
void LGRuntimePerformOnLatencyLane(LGRuntimeLatencyLane lane, dispatch_block_t block);
BOOL LGRuntimeCurrentThreadLatencyCritical(void);
void LGRuntimeLatencyYield(void);
dispatch_queue_t LGRuntimeTransferQueue(void);
dispatch_queue_t LGRuntimeQueueForPriority(LGRuntimePriority priority);
void LGRuntimeDispatch(LGRuntimePriority priority, dispatch_block_t block);
void LGRuntimeDispatchPreload(id<NSCopying> key, dispatch_block_t block);
void LGRuntimeDispatchAfter(LGRuntimePriority priority, NSTimeInterval delay, dispatch_block_t block);
void LGRuntimeDispatchCoalesced(NSString *key, LGRuntimePriority priority, NSTimeInterval delay, dispatch_block_t block);
void LGRuntimeCancelCoalesced(NSString *key);
void LGRuntimeDispatchAfterStartupPhase(LGRuntimePriority priority, dispatch_block_t block);
void LGRuntimeCompleteStartupPhase(NSString *reason);
void LGRuntimeExtendStartupPhase(void);
BOOL LGRuntimeStartupPhaseCompleted(void);
void LGRuntimeCompleteStartupSync(void);
void LGRuntimeDispatchAfterFirstFrame(LGRuntimePriority priority, dispatch_block_t block);
void LGRuntimeCompleteFirstFrame(void);
BOOL LGRuntimeFirstFrameCompleted(void);

#ifdef __cplusplus
}
#endif
