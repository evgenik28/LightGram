#import "LGPlatformVersion.h"
#include <pthread.h>
#import <mach/mach_time.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>

static const uint32_t LGPlatformLoadCommandVersionMinIPhoneOS = 0x25;
static const uint32_t LGPlatformLoadCommandBuildVersion = 0x32;

typedef struct
{
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t version;
    uint32_t sdk;
} LGPlatformVersionMinCommand;

typedef struct
{
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t platform;
    uint32_t minos;
    uint32_t sdk;
    uint32_t ntools;
} LGPlatformBuildVersionCommand;

NSInteger LGPlatformMajorVersion(void)
{
    static NSInteger value = -1;
    if (value >= 0)
        return value;
    @synchronized([UIDevice class])
    {
        if (value < 0)
        {
            NSString *version = [[UIDevice currentDevice] systemVersion];
            NSRange range = [version rangeOfString:@"."];
            NSString *major = range.location == NSNotFound ? version : [version substringToIndex:range.location];
            value = [major integerValue];
            if (value < 0)
                value = 0;
        }
    }
    return value;
}

BOOL LGPlatformSupportsBackgroundVoipTransport(void)
{
    static NSInteger value = -1;
    if (value >= 0)
        return value != 0;
    @synchronized([UIApplication class])
    {
        if (value < 0)
            value = LGPlatformMajorVersion() <= 9 && [UIApplication instancesRespondToSelector:NSSelectorFromString(@"setKeepAliveTimeout:handler:")] ? 1 : 0;
    }
    return value != 0;
}

BOOL LGPlatformSystemVersionAtLeast(CGFloat version)
{
    static double value = -1.0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        value = [[[UIDevice currentDevice] systemVersion] doubleValue];
    });
    return value + 0.0001 >= version;
}

static NSInteger LGPlatformLinkedSDKMajorVersion(void)
{
    static NSInteger value = -1;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        value = 0;
        const struct mach_header *header = _dyld_get_image_header(0);
        if (header == NULL)
            return;

        const uint8_t *cursor = NULL;
        if (header->magic == MH_MAGIC_64)
            cursor = (const uint8_t *)header + sizeof(struct mach_header_64);
        else if (header->magic == MH_MAGIC)
            cursor = (const uint8_t *)header + sizeof(struct mach_header);
        else
            return;

        for (uint32_t index = 0; index < header->ncmds; index++)
        {
            const struct load_command *command = (const struct load_command *)cursor;
            if (command->cmd == LGPlatformLoadCommandVersionMinIPhoneOS)
            {
                value = ((const LGPlatformVersionMinCommand *)cursor)->sdk >> 16;
                return;
            }
            if (command->cmd == LGPlatformLoadCommandBuildVersion)
            {
                value = ((const LGPlatformBuildVersionCommand *)cursor)->sdk >> 16;
                return;
            }
            cursor += command->cmdsize;
        }
    });
    return value;
}

BOOL LGPlatformSupportsAdaptivePresentation(void)
{
    return LGPlatformMajorVersion() >= 8 && LGPlatformLinkedSDKMajorVersion() >= 8;
}

NSTimeInterval LGPlatformSystemUptime(void)
{
    mach_timebase_info_data_t timebase;
    if (mach_timebase_info(&timebase) != 0 || timebase.denom == 0)
        return 0.0;
    return ((double)mach_absolute_time() * (double)timebase.numer / (double)timebase.denom) / 1000000000.0;
}

CGFloat LGPlatformScreenScale(void)
{
    UIScreen *screen = [UIScreen mainScreen];
    SEL selector = NSSelectorFromString(@"scale");
    if ([screen respondsToSelector:selector])
    {
        CGFloat (*function)(id, SEL) = (CGFloat (*)(id, SEL))[screen methodForSelector:selector];
        if (function != NULL)
        {
            CGFloat scale = function(screen, selector);
            if (scale >= 1.0f)
                return scale;
        }
    }
    return 1.0f;
}

NSString *LGPlatformScreenBrightnessDidChangeNotification(void)
{
    return @"UIScreenBrightnessDidChangeNotification";
}

CGFloat LGPlatformScreenBrightness(void)
{
    UIScreen *screen = [UIScreen mainScreen];
    SEL selector = NSSelectorFromString(@"brightness");
    if ([screen respondsToSelector:selector])
    {
        CGFloat (*function)(id, SEL) = (CGFloat (*)(id, SEL))[screen methodForSelector:selector];
        if (function != NULL)
            return MIN(1.0f, MAX(0.0f, function(screen, selector)));
    }
    CFPropertyListRef value = CFPreferencesCopyAppValue(CFSTR("SBBacklightLevel2"), CFSTR("com.apple.springboard"));
    CGFloat brightness = 0.5f;
    if (value != NULL)
    {
        if (CFGetTypeID(value) == CFNumberGetTypeID())
        {
            float storedBrightness = (float)brightness;
            CFNumberGetValue((CFNumberRef)value, kCFNumberFloatType, &storedBrightness);
            brightness = storedBrightness;
        }
        CFRelease(value);
    }
    return MIN(1.0f, MAX(0.0f, brightness));
}

void LGPlatformSetScreenBrightness(CGFloat brightness)
{
    brightness = MIN(1.0f, MAX(0.0f, brightness));
    UIScreen *screen = [UIScreen mainScreen];
    SEL selector = NSSelectorFromString(@"setBrightness:");
    if ([screen respondsToSelector:selector])
    {
        void (*function)(id, SEL, CGFloat) = (void (*)(id, SEL, CGFloat))[screen methodForSelector:selector];
        if (function != NULL)
            function(screen, selector, brightness);
        return;
    }
    void *graphicsServices = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_LAZY | RTLD_LOCAL);
    void (*setBacklightLevel)(float) = graphicsServices == NULL ? NULL : (void (*)(float))dlsym(graphicsServices, "GSEventSetBacklightLevel");
    if (setBacklightLevel != NULL)
        setBacklightLevel((float)brightness);
    float storedBrightness = (float)brightness;
    CFNumberRef value = CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &storedBrightness);
    if (value != NULL)
    {
        CFPreferencesSetAppValue(CFSTR("SBBacklightLevel2"), value, CFSTR("com.apple.springboard"));
        CFPreferencesAppSynchronize(CFSTR("com.apple.springboard"));
        CFRelease(value);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:LGPlatformScreenBrightnessDidChangeNotification() object:screen];
}

BOOL LGPlatformClassAvailable(NSString *className)
{
    if ([className length] == 0)
        return NO;
    return NSClassFromString(className) != Nil;
}

BOOL LGPlatformObjectResponds(id object, NSString *selectorName)
{
    if (object == nil || [selectorName length] == 0)
        return NO;
    return [object respondsToSelector:NSSelectorFromString(selectorName)];
}

BOOL LGPlatformSupportsRegionalIndicatorEmoji(void)
{
    return LGPlatformMajorVersion() >= 5;
}

static pthread_mutex_t LGPlatformDefaultsCacheLock = PTHREAD_MUTEX_INITIALIZER;
static NSMutableDictionary *LGPlatformDefaultsCache = nil;

void LGPlatformInvalidateCachedDefaults(void)
{
    pthread_mutex_lock(&LGPlatformDefaultsCacheLock);
    [LGPlatformDefaultsCache removeAllObjects];
    pthread_mutex_unlock(&LGPlatformDefaultsCacheLock);
}

static NSNumber *LGPlatformCachedDefault(NSString *key)
{
    if (key == nil)
        return nil;
    pthread_mutex_lock(&LGPlatformDefaultsCacheLock);
    if (LGPlatformDefaultsCache == nil)
    {
        LGPlatformDefaultsCache = [[NSMutableDictionary alloc] init];
        [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:nil usingBlock:^(__unused NSNotification *notification)
        {
            LGPlatformInvalidateCachedDefaults();
        }];
    }
    id value = LGPlatformDefaultsCache[key];
    pthread_mutex_unlock(&LGPlatformDefaultsCacheLock);
    if (value == nil)
    {
        id stored = [[NSUserDefaults standardUserDefaults] objectForKey:key];
        value = [stored isKindOfClass:[NSNumber class]] ? stored : (stored != nil && [stored respondsToSelector:@selector(integerValue)] ? @([stored integerValue]) : [NSNull null]);
        pthread_mutex_lock(&LGPlatformDefaultsCacheLock);
        LGPlatformDefaultsCache[key] = value;
        pthread_mutex_unlock(&LGPlatformDefaultsCacheLock);
    }
    return value == [NSNull null] ? nil : value;
}

BOOL LGPlatformCachedBoolDefault(NSString *key)
{
    return [LGPlatformCachedDefault(key) boolValue];
}

NSInteger LGPlatformCachedIntegerDefault(NSString *key, NSInteger missingValue)
{
    NSNumber *value = LGPlatformCachedDefault(key);
    return value != nil ? [value integerValue] : missingValue;
}
