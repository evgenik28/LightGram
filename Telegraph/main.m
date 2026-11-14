#include <mach/mach_time.h>
#import "../LightGramRuntime/LGStartupDiagnostics.h"
#import <UIKit/UIKit.h>

#import "TGAppDelegate.h"
#import "TGApplication.h"

#import "TGDatabase.h"
#import "TGAccountManager.h"
#import "../LightGramRuntime/LGRuntime.h"
#import "../LightGramRuntime/LGDiagnostics.h"

int main(int argc, char *argv[])
{
    uint64_t startupTicks = mach_absolute_time();
    NSTimeInterval startupUnixTime = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970;
    @autoreleasepool
    {
        LGDiagnosticsActivate(LGDiagnosticsComponentLightGram, [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"OGLightGramBuildDiagnostics"] boolValue]);
        LGDiagnosticsTimingBegin("cold_start");
    }
    LGRuntimeConfigureMainThread();
    mainLaunchTimestamp = CFAbsoluteTimeGetCurrent();
    applicationStartupTimestamp = mainLaunchTimestamp;
    @autoreleasepool
    {
        if (LGDiagnosticsEnabled())
            LGStartupDiagnosticsInitialize(startupTicks, startupUnixTime);
        [TGAccountManager performLaunchRecovery];
        [TGDatabase setDatabaseName:@"tgdata"];
        
        return UIApplicationMain(argc, argv, @"TGApplication", @"TGAppDelegate");
    }
}
