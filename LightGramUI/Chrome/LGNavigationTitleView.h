#import "../Base/LGView.h"

@interface LGNavigationTitleView : LGView
@property (nonatomic, retain, readonly) UILabel *titleLabel;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) BOOL (^accessibilityActivation)(void);
@end
