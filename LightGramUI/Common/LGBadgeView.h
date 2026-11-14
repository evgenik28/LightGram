#import "../Base/LGView.h"
@class LGLabel;
@interface LGBadgeView : LGView
@property (nonatomic) NSInteger count;
@property (nonatomic, copy) NSString *displayText;
@property (nonatomic, retain, readonly) LGLabel *textLabel;
@end
