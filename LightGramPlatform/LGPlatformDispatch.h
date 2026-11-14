#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

FOUNDATION_EXPORT void LGPlatformDispatchOnMainThread(void (^block)(void));
FOUNDATION_EXPORT void LGPlatformDispatchAfterCurrentMainRunLoop(void (^block)(void));
FOUNDATION_EXPORT void LGPlatformDispatchOnMainThreadAfter(NSTimeInterval delay, void (^block)(void));
FOUNDATION_EXPORT dispatch_queue_t LGPlatformBackgroundQueue(void);
FOUNDATION_EXPORT dispatch_queue_t LGPlatformBackgroundLowQueue(void);
FOUNDATION_EXPORT bool LGPlatformUsesConstrainedBackgroundExecution(void);
FOUNDATION_EXPORT void LGPlatformDiagnosticLog(NSString *format, ...) __attribute__((format(__NSString__, 1, 2)));
