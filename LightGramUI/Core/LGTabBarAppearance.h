#import <UIKit/UIKit.h>

@class LGSurfaceStyle;

@interface LGTabBarSegmentStyle : NSObject
@property (nonatomic, copy) NSArray *colors;
@property (nonatomic, copy) NSArray *locations;
@property (nonatomic, copy) NSArray *shadows;
@property (nonatomic, retain) UIColor *trailingEdgeColor;
@property (nonatomic) BOOL trailingEdgeAboveNeighbor;
@end

@interface LGTabBarLayout : NSObject
@property (nonatomic, retain) LGTabBarSegmentStyle *segmentStyle;
@property (nonatomic, retain) LGTabBarSegmentStyle *selectedSegmentStyle;
@property (nonatomic) CGFloat iconTopInset;
@property (nonatomic) CGFloat titleBottomInset;
@property (nonatomic) CGFloat titleHeight;
@end

@interface LGTabBarAppearance : NSObject
@property (nonatomic, retain) UIFont *titleFont;
@property (nonatomic, retain) UIColor *titleColor;
@property (nonatomic, retain) UIColor *titleShadowColor;
@property (nonatomic) CGSize titleShadowOffset;
@property (nonatomic) CGFloat titleShadowRadius;
@property (nonatomic, copy) NSArray *iconGradientColors;
@property (nonatomic, copy) NSArray *iconGradientLocations;
@property (nonatomic, copy) NSArray *iconShadows;
@property (nonatomic, copy) NSArray *selectedIconGradientColors;
@property (nonatomic, copy) NSArray *selectedIconGradientLocations;
@property (nonatomic, copy) NSArray *selectedIconShadows;
@property (nonatomic, retain) LGTabBarLayout *compactLayout;
@property (nonatomic, retain) LGTabBarLayout *regularLayout;
@property (nonatomic) NSUInteger regularLayoutMinimumItemCount;
- (LGTabBarLayout *)layoutForItemCount:(NSUInteger)itemCount;
- (UIEdgeInsets)iconOutsets;
- (LGSurfaceStyle *)backgroundStyleWithSegmentFrames:(NSArray *)segmentFrames selectedIndex:(NSInteger)selectedIndex;
+ (LGTabBarAppearance *)brandedAppearance;
@end
