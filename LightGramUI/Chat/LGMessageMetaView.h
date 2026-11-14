#import "../Base/LGView.h"
#import "../Core/LGState.h"
@class LGLabel;
@class LGCheckmarkView;
@interface LGMessageMetaView : LGView
@property (nonatomic, retain, readonly) LGLabel *timeLabel;
@property (nonatomic, retain, readonly) LGLabel *viewsLabel;
@property (nonatomic, retain, readonly) LGCheckmarkView *checkmarkView;
@property (nonatomic, copy) NSString *timeText;
@property (nonatomic, copy) NSString *viewsText;
@property (nonatomic) LGDeliveryState deliveryState;
@property (nonatomic) BOOL outgoing;
@end
