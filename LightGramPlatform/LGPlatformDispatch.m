#import "LGPlatformDispatch.h"
#import "LGPlatformVersion.h"
#import <dispatch/dispatch.h>

void LGPlatformDispatchOnMainThread(void (^block)(void))
{
    if (block == nil)
        return;
    if ([NSThread isMainThread])
    {
        block();
        return;
    }
    dispatch_async(dispatch_get_main_queue(), block);
}

void LGPlatformDispatchAfterCurrentMainRunLoop(void (^block)(void))
{
    if (block == nil)
        return;
    dispatch_async(dispatch_get_main_queue(), block);
}


bool LGPlatformUsesConstrainedBackgroundExecution(void)
{
    return LGPlatformMajorVersion() <= 3;
}

dispatch_queue_t LGPlatformBackgroundQueue(void)
{
    if (!LGPlatformUsesConstrainedBackgroundExecution())
        return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("dev.notdevv.LightGram.legacy-background", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

dispatch_queue_t LGPlatformBackgroundLowQueue(void)
{
    if (!LGPlatformUsesConstrainedBackgroundExecution())
        return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("dev.notdevv.LightGram.legacy-background-low", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
    });
    return queue;
}

void LGPlatformDispatchOnMainThreadAfter(NSTimeInterval delay, void (^block)(void))
{
    if (block == nil)
        return;
    if (delay <= 0.0)
    {
        LGPlatformDispatchOnMainThread(block);
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
    {
        @autoreleasepool
        {
            LGPlatformDispatchOnMainThread(block);
        }
    });
}

static dispatch_queue_t LGPlatformDiagnosticLogQueue(void)
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("org.lightgram.diagnostic.syslog", NULL);
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
    });
    return queue;
}

void LGPlatformDiagnosticLog(NSString *format, ...)
{
    if (format == nil || !LGDiagnosticsEnabled())
        return;
    va_list arguments;
    va_start(arguments, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    dispatch_async(LGPlatformDiagnosticLogQueue(), ^
    {
        NSLog(@"%@", message);
    });
}
