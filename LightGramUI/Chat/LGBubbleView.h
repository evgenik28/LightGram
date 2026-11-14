#import "../Base/LGView.h"
#import "../Core/LGState.h"
@interface LGBubbleView : LGView
@property (nonatomic) LGMessageAlignment alignment;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) BOOL drawsTail;
@end
