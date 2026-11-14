#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

struct sqlite3;

#ifdef __cplusplus
extern "C" {
#endif

void LGDatabaseRuntimeDispatch(dispatch_queue_t queue, BOOL synchronous, dispatch_block_t block);
void LGDatabaseRuntimeDispatchContinuation(dispatch_queue_t queue, dispatch_block_t block);
void LGDatabaseRuntimeDispatchBackground(dispatch_queue_t queue, dispatch_block_t block);
void LGDatabaseRuntimeDispatchInteractive(dispatch_queue_t queue, dispatch_block_t block);
BOOL LGDatabaseRuntimePriorityWorkPending(void);
BOOL LGDatabaseRuntimeForegroundWorkPending(void);
void LGDatabaseRuntimeBeginStartupCritical(void);
void LGDatabaseRuntimeEndStartupCritical(void);
void LGDatabaseRuntimeInteractionStateChanged(void);
void LGDatabaseRuntimeCooperateDuringInteraction(void);
void LGDatabaseRuntimeConfigureSQLite(struct sqlite3 *database);

#ifdef __cplusplus
}
#endif
