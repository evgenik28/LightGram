#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSInteger LGPlatformMajorVersion(void);
FOUNDATION_EXPORT BOOL LGPlatformSupportsBackgroundVoipTransport(void);
FOUNDATION_EXPORT BOOL LGPlatformSystemVersionAtLeast(CGFloat version);
FOUNDATION_EXPORT BOOL LGPlatformSupportsAdaptivePresentation(void);
FOUNDATION_EXPORT NSTimeInterval LGPlatformSystemUptime(void);
FOUNDATION_EXPORT CGFloat LGPlatformScreenScale(void);
FOUNDATION_EXPORT CGFloat LGPlatformScreenBrightness(void);
FOUNDATION_EXPORT void LGPlatformSetScreenBrightness(CGFloat brightness);
FOUNDATION_EXPORT NSString *LGPlatformScreenBrightnessDidChangeNotification(void);
FOUNDATION_EXPORT BOOL LGPlatformClassAvailable(NSString *className);
FOUNDATION_EXPORT BOOL LGPlatformObjectResponds(id object, NSString *selectorName);
FOUNDATION_EXPORT BOOL LGPlatformSupportsRegionalIndicatorEmoji(void);
FOUNDATION_EXPORT BOOL LGPlatformCachedBoolDefault(NSString *key);
FOUNDATION_EXPORT NSInteger LGPlatformCachedIntegerDefault(NSString *key, NSInteger missingValue);
FOUNDATION_EXPORT void LGPlatformInvalidateCachedDefaults(void);
