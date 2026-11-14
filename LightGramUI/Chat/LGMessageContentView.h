#import "../Base/LGView.h"
@interface LGMessageContentView : LGView
@property (nonatomic, retain) id item;
- (CGSize)contentSizeThatFits:(CGSize)size;
@end
