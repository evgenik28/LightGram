#import <UIKit/UIKit.h>
@class LGTheme;

@interface LGButton : UIButton
@property (nonatomic, retain) LGTheme *theme;
@property (nonatomic, copy) NSString *normalAssetName;
@property (nonatomic, copy) NSString *highlightedAssetName;
- (void)applyTheme;
@end
