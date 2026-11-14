#import "LGPlatformLocation.h"

#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
#import <MapKit/MapKit.h>
#endif

static BOOL LGPlatformLocationManagerClassBoolValue(SEL selector, BOOL fallback)
{
    Class managerClass = NSClassFromString(@"CLLocationManager");
    if (managerClass == Nil || ![(id)managerClass respondsToSelector:selector])
        return fallback;

    BOOL (*function)(id, SEL) = (BOOL (*)(id, SEL))[(id)managerClass methodForSelector:selector];
    if (function == NULL)
        return fallback;

    return function((id)managerClass, selector);
}

static NSInteger LGPlatformLocationManagerClassIntegerValue(SEL selector, NSInteger fallback)
{
    Class managerClass = NSClassFromString(@"CLLocationManager");
    if (managerClass == Nil || ![(id)managerClass respondsToSelector:selector])
        return fallback;

    int (*function)(id, SEL) = (int (*)(id, SEL))[(id)managerClass methodForSelector:selector];
    if (function == NULL)
        return fallback;

    return function((id)managerClass, selector);
}

static BOOL LGPlatformLocationManagerInvoke(CLLocationManager *manager, SEL selector)
{
    if (manager == nil || ![manager respondsToSelector:selector])
        return NO;

    void (*function)(id, SEL) = (void (*)(id, SEL))[manager methodForSelector:selector];
    if (function == NULL)
        return NO;

    function(manager, selector);
    return YES;
}

static void LGPlatformLocationManagerSetBool(CLLocationManager *manager, SEL selector, BOOL value)
{
    if (manager == nil || ![manager respondsToSelector:selector])
        return;

    void (*function)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[manager methodForSelector:selector];
    if (function != NULL)
        function(manager, selector, value);
}

static void LGPlatformLocationManagerSetInteger(CLLocationManager *manager, SEL selector, NSInteger value)
{
    if (manager == nil || ![manager respondsToSelector:selector])
        return;

    void (*function)(id, SEL, NSInteger) = (void (*)(id, SEL, NSInteger))[manager methodForSelector:selector];
    if (function != NULL)
        function(manager, selector, value);
}

LGPlatformLocationAuthorizationStatus LGPlatformLocationAuthorizationStatusCurrent(void)
{
    Class managerClass = NSClassFromString(@"CLLocationManager");
    SEL authorizationSelector = NSSelectorFromString(@"authorizationStatus");
    if (managerClass != Nil && [(id)managerClass respondsToSelector:authorizationSelector])
        return LGPlatformLocationManagerClassIntegerValue(authorizationSelector, LGPlatformLocationAuthorizationStatusNotDetermined);

    SEL enabledSelector = NSSelectorFromString(@"locationServicesEnabled");
    if (managerClass != Nil && [(id)managerClass respondsToSelector:enabledSelector] && !LGPlatformLocationManagerClassBoolValue(enabledSelector, YES))
        return LGPlatformLocationAuthorizationStatusDenied;

    return LGPlatformLocationAuthorizationStatusAuthorized;
}

BOOL LGPlatformLocationAuthorizationStatusAllowsWhenInUse(LGPlatformLocationAuthorizationStatus status)
{
    return status == LGPlatformLocationAuthorizationStatusAuthorized || status == LGPlatformLocationAuthorizationStatusAuthorizedWhenInUse;
}

BOOL LGPlatformLocationAuthorizationStatusAllowsAlways(LGPlatformLocationAuthorizationStatus status)
{
    return status == LGPlatformLocationAuthorizationStatusAuthorizedAlways;
}

BOOL LGPlatformLocationAuthorizationAllowsWhenInUse(void)
{
    return LGPlatformLocationAuthorizationStatusAllowsWhenInUse(LGPlatformLocationAuthorizationStatusCurrent());
}

BOOL LGPlatformLocationAuthorizationAllowsAlways(void)
{
    return LGPlatformLocationAuthorizationStatusAllowsAlways(LGPlatformLocationAuthorizationStatusCurrent());
}

BOOL LGPlatformRequestWhenInUseLocationAuthorization(CLLocationManager *manager)
{
    if (manager == nil)
        return NO;

    if (LGPlatformLocationManagerInvoke(manager, NSSelectorFromString(@"requestWhenInUseAuthorization")))
        return YES;

    [manager startUpdatingLocation];
    return YES;
}

BOOL LGPlatformRequestAlwaysLocationAuthorization(CLLocationManager *manager)
{
    if (manager == nil)
        return NO;

    if (LGPlatformLocationManagerInvoke(manager, NSSelectorFromString(@"requestAlwaysAuthorization")))
        return YES;

    [manager startUpdatingLocation];
    return YES;
}

BOOL LGPlatformRequestSingleLocation(CLLocationManager *manager)
{
    if (manager == nil)
        return NO;

    if (LGPlatformLocationManagerInvoke(manager, NSSelectorFromString(@"requestLocation")))
        return YES;

    [manager startUpdatingLocation];
    return YES;
}

void LGPlatformSetLocationActivityTypeOther(CLLocationManager *manager)
{
    LGPlatformLocationManagerSetInteger(manager, NSSelectorFromString(@"setActivityType:"), 1);
}

void LGPlatformSetLocationPausesAutomatically(CLLocationManager *manager, BOOL enabled)
{
    LGPlatformLocationManagerSetBool(manager, NSSelectorFromString(@"setPausesLocationUpdatesAutomatically:"), enabled);
}

void LGPlatformSetLocationAllowsBackgroundUpdates(CLLocationManager *manager, BOOL enabled)
{
    LGPlatformLocationManagerSetBool(manager, NSSelectorFromString(@"setAllowsBackgroundLocationUpdates:"), enabled);
}

void LGPlatformOpenMaps(double latitude, double longitude, BOOL directions)
{
    CLLocationCoordinate2D coordinate = {latitude, longitude};
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    MKPlacemark *placemark = [[MKPlacemark alloc] initWithCoordinate:coordinate addressDictionary:nil];
    MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placemark];
    if (directions)
    {
        NSDictionary *options = @{MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving};
        [MKMapItem openMapsWithItems:@[[MKMapItem mapItemForCurrentLocation], mapItem] launchOptions:options];
    }
    else
    {
        [mapItem openInMapsWithLaunchOptions:nil];
    }
#else
    NSString *urlString = directions ? [NSString stringWithFormat:@"http://maps.google.com/maps?saddr=Current%%20Location&daddr=%f,%f", coordinate.latitude, coordinate.longitude] : [NSString stringWithFormat:@"http://maps.google.com/maps?q=%f,%f", coordinate.latitude, coordinate.longitude];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
#endif
}
