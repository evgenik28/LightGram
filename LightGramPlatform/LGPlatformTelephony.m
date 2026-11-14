#import "LGPlatformTelephony.h"

#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <objc/message.h>

static id LGPlatformTelephonyObject(id object, NSString *selectorName)
{
    SEL selector = NSSelectorFromString(selectorName);
    if (object == nil || ![object respondsToSelector:selector])
        return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static id LGPlatformNetworkInfo(void)
{
    Class networkInfoClass = NSClassFromString(@"CTTelephonyNetworkInfo");
    return networkInfoClass == Nil ? nil : [[networkInfoClass alloc] init];
}

static NSString *LGPlatformModernCarrierValue(NSString *selectorName)
{
    id networkInfo = LGPlatformNetworkInfo();
    id carrier = LGPlatformTelephonyObject(networkInfo, @"subscriberCellularProvider");
    id value = LGPlatformTelephonyObject(carrier, selectorName);
    return [value isKindOfClass:[NSString class]] ? [value copy] : nil;
}

static void *LGPlatformLegacyCoreTelephony(void)
{
    static void *handle = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handle = dlopen("/System/Library/PrivateFrameworks/CoreTelephony.framework/CoreTelephony", RTLD_LAZY | RTLD_LOCAL);
    });
    return handle;
}

static NSString *LGPlatformLegacySIMValue(const char *symbolName)
{
    void *handle = LGPlatformLegacyCoreTelephony();
    if (handle == NULL)
        return nil;
    CFStringRef (*function)(CFAllocatorRef) = (CFStringRef (*)(CFAllocatorRef))dlsym(handle, symbolName);
    if (function == NULL)
        return nil;
    CFStringRef value = function(kCFAllocatorDefault);
    return value == NULL ? nil : (__bridge_transfer NSString *)value;
}

NSString *LGPlatformCarrierISOCountryCode(void)
{
    return LGPlatformModernCarrierValue(@"isoCountryCode");
}

NSString *LGPlatformCarrierMobileCountryCode(void)
{
    NSString *value = LGPlatformModernCarrierValue(@"mobileCountryCode");
    return value != nil ? value : LGPlatformLegacySIMValue("CTSIMSupportCopyMobileSubscriberCountryCode");
}

NSString *LGPlatformCarrierMobileNetworkCode(void)
{
    NSString *value = LGPlatformModernCarrierValue(@"mobileNetworkCode");
    return value != nil ? value : LGPlatformLegacySIMValue("CTSIMSupportCopyMobileSubscriberNetworkCode");
}

BOOL LGPlatformIsOnPhoneCall(void)
{
    Class callCenterClass = NSClassFromString(@"CTCallCenter");
    if (callCenterClass != Nil)
    {
        id callCenter = [[callCenterClass alloc] init];
        id calls = LGPlatformTelephonyObject(callCenter, @"currentCalls");
        for (id call in calls)
        {
            NSString *state = LGPlatformTelephonyObject(call, @"callState");
            if ([state isEqualToString:@"CTCallStateConnected"])
                return YES;
        }
        return NO;
    }

    void *handle = LGPlatformLegacyCoreTelephony();
    if (handle == NULL)
        return NO;
    CFArrayRef (*function)(CFAllocatorRef) = (CFArrayRef (*)(CFAllocatorRef))dlsym(handle, "CTCopyCurrentCalls");
    if (function == NULL)
        return NO;
    CFArrayRef calls = function(kCFAllocatorDefault);
    BOOL result = calls != NULL && CFArrayGetCount(calls) != 0;
    if (calls != NULL)
        CFRelease(calls);
    return result;
}
