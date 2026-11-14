#import "LGDiagnostics.h"
#import "LGDiagnosticsLogging.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <notify.h>

#define LGHelperDiagnosticsLightGramKey "LightGram"
#define LGHelperDiagnosticsHelperKey "LightGramHelper"
#define LGHelperSharedDirectoryPath "/var/mobile/Library/LightGram"
#define LGHelperDiagnosticsSettingsPath LGHelperSharedDirectoryPath "/diagnostics.plist"
#define LGHelperDiagnosticsChangedNotification "dev.notdevv.LightGram.helper.diagnostics"

bool LGDiagnosticsActive = false;

NSString *const LGDiagnosticsFirstDialogFrameNotification = @"LGDiagnosticsFirstDialogFrameNotification";

static NSMutableDictionary *LGDiagnosticsTimingStarts = nil;
static NSMutableSet *LGDiagnosticsTimingRecorded = nil;
static NSMutableSet *LGDiagnosticsTimingPendingFrames = nil;
static bool LGDiagnosticsFirstDialogFrameScheduled = false;

@interface LGDiagnosticsFrameProbe : NSObject

@property (nonatomic, strong) UIView *view;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, copy) NSString *scenario;
@property (nonatomic) bool firstDialogFrame;
@property (nonatomic) bool once;
@property (nonatomic) NSUInteger ticks;

- (void)tick:(CADisplayLink *)link;

@end

@interface LGDiagnosticsForegroundProbe : NSObject

@end

static bool LGDiagnosticsForegroundPending = false;

@implementation LGDiagnosticsForegroundProbe

+ (void)load
{
    if ([NSBundle bundleForClass:self] != [NSBundle mainBundle])
        return;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [center addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

+ (void)willEnterForeground:(NSNotification *)__unused notification
{
    LGDiagnosticsForegroundPending = true;
    LGDiagnosticsTimingBegin("foreground_first_frame");
}

+ (void)didBecomeActive:(NSNotification *)__unused notification
{
    if (!LGDiagnosticsForegroundPending)
        return;
    LGDiagnosticsForegroundPending = false;
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (window != nil && window.rootViewController != nil)
        LGDiagnosticsTimingAfterFrame("foreground_first_frame", window.rootViewController.view, false, false);
}

@end

void LGDiagnosticsTimingBegin(const char *scenario)
{
    if (!LGDiagnosticsEnabled() || scenario == NULL)
        return;
    @synchronized ([LGDiagnosticsFrameProbe class])
    {
        if (LGDiagnosticsTimingStarts == nil)
            LGDiagnosticsTimingStarts = [[NSMutableDictionary alloc] init];
        LGDiagnosticsTimingStarts[[NSString stringWithUTF8String:scenario]] = @(CFAbsoluteTimeGetCurrent());
    }
}

void LGDiagnosticsTimingBeginOnce(const char *scenario)
{
    if (!LGDiagnosticsEnabled() || scenario == NULL)
        return;
    @synchronized ([LGDiagnosticsFrameProbe class])
    {
        NSString *key = [NSString stringWithUTF8String:scenario];
        if ([LGDiagnosticsTimingRecorded containsObject:key] || LGDiagnosticsTimingStarts[key] != nil)
            return;
        if (LGDiagnosticsTimingStarts == nil)
            LGDiagnosticsTimingStarts = [[NSMutableDictionary alloc] init];
        LGDiagnosticsTimingStarts[key] = @(CFAbsoluteTimeGetCurrent());
    }
}

void LGDiagnosticsTimingEnd(const char *scenario)
{
    if (!LGDiagnosticsEnabled() || scenario == NULL)
        return;
    double milliseconds = -1.0;
    @synchronized ([LGDiagnosticsFrameProbe class])
    {
        NSString *key = [NSString stringWithUTF8String:scenario];
        NSNumber *start = LGDiagnosticsTimingStarts[key];
        if (start != nil)
        {
            milliseconds = (CFAbsoluteTimeGetCurrent() - [start doubleValue]) * 1000.0;
            [LGDiagnosticsTimingStarts removeObjectForKey:key];
            if (LGDiagnosticsTimingRecorded == nil)
                LGDiagnosticsTimingRecorded = [[NSMutableSet alloc] init];
            [LGDiagnosticsTimingRecorded addObject:key];
        }
    }
    if (milliseconds >= 0.0)
        NSLog(@"TIMING %s %.1f", scenario, milliseconds);
}

void LGDiagnosticsTimingRecordOnce(const char *scenario, double milliseconds)
{
    if (!LGDiagnosticsEnabled() || scenario == NULL || milliseconds < 0.0)
        return;
    bool record = false;
    @synchronized ([LGDiagnosticsFrameProbe class])
    {
        NSString *key = [NSString stringWithUTF8String:scenario];
        if (![LGDiagnosticsTimingRecorded containsObject:key])
        {
            if (LGDiagnosticsTimingRecorded == nil)
                LGDiagnosticsTimingRecorded = [[NSMutableSet alloc] init];
            [LGDiagnosticsTimingRecorded addObject:key];
            record = true;
        }
    }
    if (record)
        NSLog(@"TIMING %s %.1f", scenario, milliseconds);
}

void LGDiagnosticsTimingAfterFrame(const char *scenario, UIView *view, bool firstDialogFrame, bool once)
{
    if (![NSThread isMainThread] || view == nil || (!firstDialogFrame && !LGDiagnosticsEnabled()))
        return;
    NSString *key = scenario != NULL ? [NSString stringWithUTF8String:scenario] : nil;
    if (once)
    {
        @synchronized ([LGDiagnosticsFrameProbe class])
        {
            if (key == nil || LGDiagnosticsTimingStarts[key] == nil ||
                [LGDiagnosticsTimingRecorded containsObject:key] || [LGDiagnosticsTimingPendingFrames containsObject:key])
                return;
            if (LGDiagnosticsTimingPendingFrames == nil)
                LGDiagnosticsTimingPendingFrames = [[NSMutableSet alloc] init];
            [LGDiagnosticsTimingPendingFrames addObject:key];
        }
    }
    if (firstDialogFrame)
    {
        @synchronized ([LGDiagnosticsFrameProbe class])
        {
            if (LGDiagnosticsFirstDialogFrameScheduled)
                return;
            LGDiagnosticsFirstDialogFrameScheduled = true;
        }
    }
    LGDiagnosticsFrameProbe *probe = [[LGDiagnosticsFrameProbe alloc] init];
    probe.view = view;
    probe.scenario = key;
    probe.firstDialogFrame = firstDialogFrame;
    probe.once = once;
    probe.displayLink = [CADisplayLink displayLinkWithTarget:probe selector:@selector(tick:)];
    [probe.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

@implementation LGDiagnosticsFrameProbe

- (void)tick:(CADisplayLink *)link
{
    if (++_ticks < 2)
        return;
    LGDiagnosticsFrameProbe *probe = self;
    [link invalidate];
    probe.displayLink = nil;
    if (probe.once)
    {
        @synchronized ([LGDiagnosticsFrameProbe class])
        {
            [LGDiagnosticsTimingPendingFrames removeObject:probe.scenario];
        }
    }
    if (probe.view.window == nil)
    {
        if (probe.firstDialogFrame)
        {
            @synchronized ([LGDiagnosticsFrameProbe class])
            {
                LGDiagnosticsFirstDialogFrameScheduled = false;
            }
        }
        return;
    }
    if (probe.scenario != nil)
        LGDiagnosticsTimingEnd(probe.scenario.UTF8String);
    if (probe.firstDialogFrame)
        [[NSNotificationCenter defaultCenter] postNotificationName:LGDiagnosticsFirstDialogFrameNotification object:nil];
}

@end

static NSString *LGDiagnosticsKey(LGDiagnosticsComponent component)
{
    switch (component)
    {
        case LGDiagnosticsComponentLightGram:
            return @LGHelperDiagnosticsLightGramKey;
        case LGDiagnosticsComponentHelper:
            return @LGHelperDiagnosticsHelperKey;
    }
    return nil;
}

static NSDictionary *LGDiagnosticsReadSettings(void)
{
    NSDictionary *settings = [[NSDictionary alloc] initWithContentsOfFile:@LGHelperDiagnosticsSettingsPath];
    return [settings isKindOfClass:[NSDictionary class]] ? settings : nil;
}

bool LGDiagnosticsOverride(LGDiagnosticsComponent component, bool *value)
{
    @autoreleasepool
    {
        NSString *key = LGDiagnosticsKey(component);
        id stored = key == nil ? nil : [LGDiagnosticsReadSettings() objectForKey:key];
        if (![stored isKindOfClass:[NSNumber class]])
            return false;
        if (value != NULL)
            *value = [stored boolValue];
        return true;
    }
}

bool LGDiagnosticsSetOverride(LGDiagnosticsComponent component, bool value)
{
    @autoreleasepool
    {
        NSString *key = LGDiagnosticsKey(component);
        if (key == nil)
            return false;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager createDirectoryAtPath:@LGHelperSharedDirectoryPath withIntermediateDirectories:true attributes:nil error:NULL])
            return false;
        NSMutableDictionary *settings = [[NSMutableDictionary alloc] initWithDictionary:LGDiagnosticsReadSettings() ?: @{}];
        [settings setObject:[NSNumber numberWithBool:value] forKey:key];
        if (![settings writeToFile:@LGHelperDiagnosticsSettingsPath atomically:true])
            return false;
        notify_post(LGHelperDiagnosticsChangedNotification);
        return true;
    }
}

bool LGDiagnosticsResolve(LGDiagnosticsComponent component, bool buildDefault)
{
    bool value = buildDefault;
    LGDiagnosticsOverride(component, &value);
    return value;
}

void LGDiagnosticsActivate(LGDiagnosticsComponent component, bool buildDefault)
{
    LGDiagnosticsActive = LGDiagnosticsResolve(component, buildDefault);
}
