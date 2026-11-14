#import "../Base/LGView.h"
@class LGLabel;
@class LGNavigationButton;
@class LGImageView;
@interface LGNavigationBar : LGView
@property (nonatomic, retain, readonly) LGImageView *backgroundView;
@property (nonatomic, retain, readonly) LGLabel *titleLabel;
@property (nonatomic, retain, readonly) LGNavigationButton *leftButton;
@property (nonatomic, retain, readonly) LGNavigationButton *rightButton;
@property (nonatomic, copy) NSString *backgroundAssetDirectory;
@property (nonatomic, copy) NSString *backgroundAssetName;
@end
