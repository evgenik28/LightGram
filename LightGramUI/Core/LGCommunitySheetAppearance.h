#import <UIKit/UIKit.h>

@class LGSurfaceStyle;
@class LGNavigationAppearance;

@interface LGCommunitySheetAppearance : NSObject
@property (nonatomic, retain) UIColor *dimColor;
@property (nonatomic) CGFloat collapsedHeightFraction;
@property (nonatomic) CGFloat headerHeight;
@property (nonatomic, retain) LGSurfaceStyle *headerSurfaceStyle;
@property (nonatomic, retain) UIColor *indicatorColor;
@property (nonatomic) CGFloat indicatorSpacing;
+ (LGCommunitySheetAppearance *)brandedAppearanceDark:(BOOL)dark navigationAppearance:(LGNavigationAppearance *)navigationAppearance;
@end
