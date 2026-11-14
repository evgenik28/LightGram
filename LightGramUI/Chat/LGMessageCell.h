#import "../Base/LGView.h"
#import "../Core/LGState.h"
@class LGBubbleView;
@class LGMessageContentView;
@class LGMessageMetaView;
@interface LGMessageCell : LGView
@property (nonatomic, retain, readonly) LGBubbleView *bubbleView;
@property (nonatomic, retain) LGMessageContentView *contentView;
@property (nonatomic, retain, readonly) LGMessageMetaView *metaView;
@property (nonatomic) LGMessageAlignment alignment;
@property (nonatomic) UIEdgeInsets bubbleInsets;
@property (nonatomic) UIEdgeInsets contentInsets;
@end
