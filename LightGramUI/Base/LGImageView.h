#import <UIKit/UIKit.h>
@class LGTheme;

@interface LGImageView : UIImageView
@property (nonatomic, retain) LGTheme *theme;
@property (nonatomic, copy) NSString *assetName;
- (void)reloadAsset;
- (void)applyTheme;
@end
