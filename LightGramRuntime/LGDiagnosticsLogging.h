#ifndef LG_DIAGNOSTICS_LOGGING_H
#define LG_DIAGNOSTICS_LOGGING_H

#if !defined(__ASSEMBLER__)
#include "LGDiagnostics.h"

#if defined(__OBJC__)
#import <Foundation/NSObjCRuntime.h>
@class UIView;
FOUNDATION_EXPORT NSString *const LGDiagnosticsFirstDialogFrameNotification;
FOUNDATION_EXPORT void LGDiagnosticsTimingBegin(const char *scenario);
FOUNDATION_EXPORT void LGDiagnosticsTimingBeginOnce(const char *scenario);
FOUNDATION_EXPORT void LGDiagnosticsTimingEnd(const char *scenario);
FOUNDATION_EXPORT void LGDiagnosticsTimingRecordOnce(const char *scenario, double milliseconds);
FOUNDATION_EXPORT void LGDiagnosticsTimingAfterFrame(const char *scenario, UIView *view, bool firstDialogFrame, bool once);
#define NSLog(...) do { if (LGDiagnosticsEnabled()) NSLog(__VA_ARGS__); } while (0)
#endif
#endif

#endif
