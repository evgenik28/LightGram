#import <UIKit/UIKit.h>
@class LGTheme;

@interface LGLabel : UILabel
@property (nonatomic, retain) LGTheme *theme;
- (void)applyTheme;
@end
