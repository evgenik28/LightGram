#import "../Base/LGButton.h"
@class LGBadgeView;
@interface LGTabBarItem : LGButton
@property (nonatomic, retain, readonly) LGBadgeView *badgeView;
@property (nonatomic) NSInteger badgeCount;
@end
