#import <UIKit/UIKit.h>

@class LGSurfaceStyle;

@interface LGNavigationAppearance : NSObject
@property (nonatomic, retain) UIFont *titleFont;
@property (nonatomic, retain) UIColor *titleColor;
@property (nonatomic, retain) UIColor *titleShadowColor;
@property (nonatomic) UIOffset titleShadowOffset;
@property (nonatomic, retain) UIFont *buttonFont;
@property (nonatomic, retain) UIColor *buttonTitleColor;
@property (nonatomic, retain) UIColor *buttonShadowColor;
@property (nonatomic) UIOffset buttonShadowOffset;
@property (nonatomic) CGFloat buttonHighlightedAlpha;
@property (nonatomic) UIOffset backButtonTitleOffset;
@property (nonatomic) UIOffset backButtonLandscapeTitleOffset;
@property (nonatomic) CGFloat backButtonBadgeTitleShift;
@property (nonatomic) UIOffset buttonTitleOffset;
@property (nonatomic) CGFloat titleVerticalOffset;
@property (nonatomic) CGFloat titleRetinaVerticalOffset;
@property (nonatomic) CGFloat titleLandscapeVerticalOffset;
@property (nonatomic) CGFloat titleViewVerticalOffset;
@property (nonatomic, retain) UIColor *tintColor;
@property (nonatomic) BOOL hidesBottomStripe;
@property (nonatomic, copy) NSString *backgroundResourceDirectory;
@property (nonatomic, copy) NSString *backgroundAssetName;
@property (nonatomic, retain) LGSurfaceStyle *backgroundSurfaceStyle;
@property (nonatomic, retain) LGSurfaceStyle *glossBackgroundSurfaceStyle;
@property (nonatomic, retain) LGSurfaceStyle *statusBackgroundSurfaceStyle;
@property (nonatomic, retain) LGSurfaceStyle *buttonSurfaceStyle;
@property (nonatomic, retain) LGSurfaceStyle *buttonPressedSurfaceStyle;
@property (nonatomic, retain) LGSurfaceStyle *backButtonSurfaceStyle;
@property (nonatomic, retain) LGSurfaceStyle *backButtonPressedSurfaceStyle;
@property (nonatomic) CGFloat buttonHeight;
@property (nonatomic) CGFloat buttonImageHeight;
@property (nonatomic) CGFloat buttonLandscapeHeight;
@property (nonatomic) CGFloat buttonLandscapeImageHeight;
@property (nonatomic) CGFloat buttonImageWidth;
@property (nonatomic) CGFloat buttonMinimumWidth;
@property (nonatomic) CGFloat buttonHorizontalPadding;
+ (LGNavigationAppearance *)brandedAppearanceDark:(BOOL)dark;
@end
