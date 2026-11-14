#import <Foundation/Foundation.h>
#include <stdint.h>

FOUNDATION_EXPORT void LGStartupDiagnosticsInitialize(uint64_t ticks, NSTimeInterval unixTime);
FOUNDATION_EXPORT BOOL LGStartupDiagnosticsIsCollecting(void);
FOUNDATION_EXPORT NSTimeInterval LGStartupDiagnosticsTime(void);
FOUNDATION_EXPORT void LGStartupDiagnosticsMark(const char *stage);
FOUNDATION_EXPORT NSString *LGStartupDiagnosticsCallers(void);
FOUNDATION_EXPORT void LGStartupDiagnosticsSyncStarted(void);
FOUNDATION_EXPORT void LGStartupDiagnosticsSyncFinished(BOOL success, const char *source);
FOUNDATION_EXPORT void LGStartupDiagnosticsNetworkState(int state);
FOUNDATION_EXPORT void LGStartupDiagnosticsUIState(BOOL normal, BOOL visible);
FOUNDATION_EXPORT void LGStartupDiagnosticsUIWorkPending(BOOL pending);
FOUNDATION_EXPORT void LGStartupDiagnosticsDialogsPresented(NSUInteger count, BOOL complete);
FOUNDATION_EXPORT void LGStartupDiagnosticsRecordDatabaseTask(const char *file, int line, NSTimeInterval execution, NSTimeInterval slowCPU, NSTimeInterval queued);
FOUNDATION_EXPORT void LGStartupDiagnosticsRecordMainDatabaseWait(NSTimeInterval duration);
