#import <UIKit/UIKit.h>

@class LGSurfaceStyle;

@interface LGDialogListAppearance : NSObject
@property (nonatomic) CGFloat rowHeight;
@property (nonatomic, retain) LGSurfaceStyle *avatarOverlaySurfaceStyle;
@property (nonatomic, retain) LGSurfaceStyle *cellBackgroundSurfaceStyle;
@property (nonatomic, retain) UIColor *messageColor;
@property (nonatomic, retain) UIColor *messageUnreadColor;
@property (nonatomic, retain) UIColor *dateColor;
@property (nonatomic, retain) UIColor *statusColor;
@property (nonatomic, retain) UIColor *disclosureColor;
@property (nonatomic, retain) UIColor *disclosureUnreadColor;
@property (nonatomic, copy) NSArray *pinGradientColors;
@property (nonatomic, retain) UIFont *mentionFont;
@property (nonatomic) CGFloat mentionOpticalSize;
@property (nonatomic, copy) NSArray *mentionGradientColors;
@property (nonatomic, copy) NSArray *mentionGradientLocations;
@property (nonatomic, copy) NSArray *mentionShadows;
@property (nonatomic, retain) LGSurfaceStyle *actionSurfaceStyle;
@property (nonatomic, copy) NSString *actionPatternAssetName;
@property (nonatomic, retain) UIColor *actionFallbackColor;
@property (nonatomic, retain) LGSurfaceStyle *headerSurfaceStyle;
@property (nonatomic, retain) UIColor *headerColor;
@property (nonatomic, retain) UIColor *folderTabsSeparatorColor;
@property (nonatomic, retain) UIColor *folderEmptyColor;
@property (nonatomic, retain) LGSurfaceStyle *folderButtonSurfaceStyle;
@property (nonatomic, retain) LGSurfaceStyle *folderButtonPressedSurfaceStyle;
@property (nonatomic, retain) UIFont *folderButtonFont;
@property (nonatomic, retain) UIColor *folderButtonTitleColor;
@property (nonatomic, retain) UIColor *folderButtonHighlightedTitleColor;
@property (nonatomic, retain) UIColor *folderButtonShadowColor;
@property (nonatomic, retain) UIColor *folderButtonHighlightedShadowColor;
@property (nonatomic) CGSize folderButtonShadowOffset;
@property (nonatomic) CGFloat folderButtonHeight;
@property (nonatomic) CGFloat folderButtonMinimumWidth;
@property (nonatomic) CGFloat folderButtonHorizontalPadding;
@property (nonatomic) CGFloat folderButtonTitleBottomInset;
@property (nonatomic) CGFloat folderTabsInset;
@property (nonatomic) CGFloat folderTabsTrailingInset;
@property (nonatomic) CGFloat folderTabsHeight;
@property (nonatomic) CGFloat folderButtonTopInset;
@property (nonatomic) CGFloat folderTabsSpacing;
@property (nonatomic) CGFloat searchBarHeight;
@property (nonatomic) UIEdgeInsets searchFieldInsets;
@property (nonatomic) CGFloat navigationButtonHorizontalInset;
@property (nonatomic) CGFloat navigationButtonVerticalOffset;
@property (nonatomic) CGFloat navigationTitleVerticalOffset;
@property (nonatomic, retain) LGSurfaceStyle *folderButtonSelectedSurfaceStyle;
@property (nonatomic, retain) LGSurfaceStyle *folderButtonSelectedPressedSurfaceStyle;
+ (LGDialogListAppearance *)brandedAppearanceDark:(BOOL)dark;
@end
