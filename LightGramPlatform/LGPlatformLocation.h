#import <Foundation/Foundation.h>

@class CLLocationManager;

typedef NSInteger LGPlatformLocationAuthorizationStatus;

enum
{
    LGPlatformLocationAuthorizationStatusNotDetermined = 0,
    LGPlatformLocationAuthorizationStatusRestricted = 1,
    LGPlatformLocationAuthorizationStatusDenied = 2,
    LGPlatformLocationAuthorizationStatusAuthorized = 3,
    LGPlatformLocationAuthorizationStatusAuthorizedAlways = 3,
    LGPlatformLocationAuthorizationStatusAuthorizedWhenInUse = 4
};

FOUNDATION_EXPORT LGPlatformLocationAuthorizationStatus LGPlatformLocationAuthorizationStatusCurrent(void);
FOUNDATION_EXPORT BOOL LGPlatformLocationAuthorizationStatusAllowsWhenInUse(LGPlatformLocationAuthorizationStatus status);
FOUNDATION_EXPORT BOOL LGPlatformLocationAuthorizationStatusAllowsAlways(LGPlatformLocationAuthorizationStatus status);
FOUNDATION_EXPORT BOOL LGPlatformLocationAuthorizationAllowsWhenInUse(void);
FOUNDATION_EXPORT BOOL LGPlatformLocationAuthorizationAllowsAlways(void);
FOUNDATION_EXPORT BOOL LGPlatformRequestWhenInUseLocationAuthorization(CLLocationManager *manager);
FOUNDATION_EXPORT BOOL LGPlatformRequestAlwaysLocationAuthorization(CLLocationManager *manager);
FOUNDATION_EXPORT BOOL LGPlatformRequestSingleLocation(CLLocationManager *manager);
FOUNDATION_EXPORT void LGPlatformSetLocationActivityTypeOther(CLLocationManager *manager);
FOUNDATION_EXPORT void LGPlatformSetLocationPausesAutomatically(CLLocationManager *manager, BOOL enabled);
FOUNDATION_EXPORT void LGPlatformSetLocationAllowsBackgroundUpdates(CLLocationManager *manager, BOOL enabled);
FOUNDATION_EXPORT void LGPlatformOpenMaps(double latitude, double longitude, BOOL directions);
