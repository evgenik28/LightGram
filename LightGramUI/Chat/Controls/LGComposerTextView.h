#import <UIKit/UIKit.h>
@class LGTheme;
@interface LGComposerTextView : UITextView
@property (nonatomic, retain) LGTheme *theme;
- (void)applyTheme;
@end
