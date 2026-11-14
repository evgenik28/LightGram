#import "LGView.h"

@interface LGIconView : LGView
@property (nonatomic, retain) UIImage *image;
@property (nonatomic, copy) NSString *assetName;
@property (nonatomic) CGSize preferredSize;
@property (nonatomic) BOOL drawsShadow;
- (void)reloadAsset;
@end
