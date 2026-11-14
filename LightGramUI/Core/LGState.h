#import <Foundation/Foundation.h>

typedef enum {
    LGControlStateNormal = 0,
    LGControlStateHighlighted = 1,
    LGControlStateDisabled = 2,
    LGControlStateSelected = 3
} LGControlState;

typedef enum {
    LGDeliveryStateNone = 0,
    LGDeliveryStateSending = 1,
    LGDeliveryStateSent = 2,
    LGDeliveryStateDelivered = 3,
    LGDeliveryStateRead = 4,
    LGDeliveryStateFailed = 5
} LGDeliveryState;

typedef enum {
    LGMessageAlignmentIncoming = 0,
    LGMessageAlignmentOutgoing = 1
} LGMessageAlignment;

typedef enum {
    LGPresenceStateUnknown = 0,
    LGPresenceStateOffline = 1,
    LGPresenceStateOnline = 2
} LGPresenceState;
