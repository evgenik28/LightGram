#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LGDeviceTier)
{
    LGDeviceTierLow,
    LGDeviceTierMedium,
    LGDeviceTierHigh
};

FOUNDATION_EXPORT LGDeviceTier LGDeviceTierCurrent(void);
FOUNDATION_EXPORT uint64_t LGDevicePhysicalMemory(void);
