#import <UIKit/UIKit.h>
@class LGTheme;

@interface LGView : UIView
@property (nonatomic, retain) LGTheme *theme;
- (void)applyTheme;
@end
