#import "LGTabBarAppearance.h"
#import "LGSurfaceStyle.h"

static UIColor *LGTabBarAppearanceRGBA(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
    return [UIColor colorWithRed:red / 255.0f green:green / 255.0f blue:blue / 255.0f alpha:alpha];
}

static UIEdgeInsets LGTabBarAppearanceUnionOutsets(UIEdgeInsets outsets, NSArray *shadows)
{
    for (LGSurfaceShadow *shadow in shadows)
    {
        UIEdgeInsets shadowOutsets = [shadow outsets];
        outsets.top = MAX(outsets.top, shadowOutsets.top);
        outsets.left = MAX(outsets.left, shadowOutsets.left);
        outsets.bottom = MAX(outsets.bottom, shadowOutsets.bottom);
        outsets.right = MAX(outsets.right, shadowOutsets.right);
    }
    return outsets;
}

@implementation LGTabBarSegmentStyle
@end

@implementation LGTabBarLayout
@end

@implementation LGTabBarAppearance

- (LGTabBarLayout *)layoutForItemCount:(NSUInteger)itemCount
{
    return itemCount >= _regularLayoutMinimumItemCount ? _regularLayout : _compactLayout;
}

- (UIEdgeInsets)iconOutsets
{
    return LGTabBarAppearanceUnionOutsets(LGTabBarAppearanceUnionOutsets(UIEdgeInsetsZero, _iconShadows), _selectedIconShadows);
}

- (LGSurfaceStyle *)backgroundStyleWithSegmentFrames:(NSArray *)segmentFrames selectedIndex:(NSInteger)selectedIndex
{
    LGTabBarLayout *layout = [self layoutForItemCount:[segmentFrames count]];
    NSMutableArray *belowEdges = [[NSMutableArray alloc] init];
    NSMutableArray *segments = [[NSMutableArray alloc] init];
    NSMutableArray *aboveEdges = [[NSMutableArray alloc] init];

    NSInteger index = 0;
    for (NSValue *value in segmentFrames)
    {
        CGRect frame = [value CGRectValue];
        LGTabBarSegmentStyle *segmentStyle = index == selectedIndex ? layout.selectedSegmentStyle : layout.segmentStyle;

        LGSurfaceLayer *segment = [[LGSurfaceLayer alloc] init];
        segment.insets = UIEdgeInsetsMake(0.0f, CGRectGetMinX(frame), 0.0f, 0.0f);
        segment.width = CGRectGetWidth(frame);
        segment.colors = segmentStyle.colors;
        segment.locations = segmentStyle.locations;
        segment.shadows = segmentStyle.shadows;
        [segments addObject:segment];

        if (segmentStyle.trailingEdgeColor != nil)
        {
            LGSurfaceLayer *edge = [[LGSurfaceLayer alloc] init];
            edge.insets = UIEdgeInsetsMake(0.0f, CGRectGetMaxX(frame), 0.0f, 0.0f);
            edge.width = 1.0f;
            edge.colors = @[segmentStyle.trailingEdgeColor, segmentStyle.trailingEdgeColor];
            edge.locations = @[@0.0f, @1.0f];
            [(segmentStyle.trailingEdgeAboveNeighbor ? aboveEdges : belowEdges) addObject:edge];
        }
        index++;
    }

    NSMutableArray *layers = [[NSMutableArray alloc] initWithArray:belowEdges];
    [layers addObjectsFromArray:segments];
    [layers addObjectsFromArray:aboveEdges];

    LGSurfaceStyle *style = [[LGSurfaceStyle alloc] init];
    style.shape = LGSurfaceShapeRoundedRect;
    style.cornerRadius = 0.0f;
    style.layers = layers;
    return style;
}

+ (LGTabBarAppearance *)brandedAppearance
{
    LGTabBarAppearance *appearance = [[LGTabBarAppearance alloc] init];

    UIFont *titleFont = [UIFont fontWithName:@"HelveticaNeue-Bold" size:10.0f];
    appearance.titleFont = titleFont != nil ? titleFont : [UIFont boldSystemFontOfSize:10.0f];
    appearance.titleColor = [UIColor whiteColor];
    appearance.titleShadowColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
    appearance.titleShadowOffset = CGSizeMake(0.0f, 1.0f);
    appearance.titleShadowRadius = 0.5f;

    appearance.iconGradientColors = @[[UIColor whiteColor], LGTabBarAppearanceRGBA(163.0f, 163.0f, 163.0f, 1.0f)];
    appearance.iconGradientLocations = @[@0.0f, @1.0f];
    appearance.iconShadows = @[
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.7f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f],
        [LGSurfaceShadow dropShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.6f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
    ];
    appearance.selectedIconGradientColors = @[[UIColor whiteColor], LGTabBarAppearanceRGBA(39.0f, 138.0f, 242.0f, 1.0f), LGTabBarAppearanceRGBA(62.0f, 201.0f, 251.0f, 1.0f)];
    appearance.selectedIconGradientLocations = @[@0.0f, @0.5f, @1.0f];
    appearance.selectedIconShadows = @[
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.6f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f],
        [LGSurfaceShadow dropShadowWithColor:LGTabBarAppearanceRGBA(4.0f, 130.0f, 255.0f, 0.8f) offset:CGSizeZero blur:3.0f],
        [LGSurfaceShadow dropShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.7f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
    ];

    NSArray *segmentColors = @[LGTabBarAppearanceRGBA(69.0f, 69.0f, 69.0f, 0.9f), LGTabBarAppearanceRGBA(57.0f, 57.0f, 57.0f, 0.9f), LGTabBarAppearanceRGBA(39.0f, 39.0f, 38.0f, 0.9f), LGTabBarAppearanceRGBA(25.0f, 25.0f, 26.0f, 0.9f)];
    NSArray *selectedSegmentColors = @[LGTabBarAppearanceRGBA(42.0f, 42.0f, 42.0f, 0.9f), LGTabBarAppearanceRGBA(53.0f, 53.0f, 53.0f, 0.9f), LGTabBarAppearanceRGBA(62.0f, 62.0f, 62.0f, 0.9f), LGTabBarAppearanceRGBA(68.0f, 68.0f, 68.0f, 0.9f)];
    NSArray *segmentLocations = @[@0.0f, @0.33f, @0.67f, @1.0f];
    NSArray *selectedSegmentShadows = @[
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.6f] offset:CGSizeMake(0.0f, 1.0f) blur:0.0f],
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.1f] offset:CGSizeMake(0.0f, 1.5f) blur:0.0f],
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.1f] offset:CGSizeMake(0.0f, 2.0f) blur:0.0f],
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.4f] offset:CGSizeMake(0.0f, 2.0f) blur:4.0f spread:1.0f]
    ];

    LGTabBarSegmentStyle *compactSegment = [[LGTabBarSegmentStyle alloc] init];
    compactSegment.colors = segmentColors;
    compactSegment.locations = segmentLocations;
    compactSegment.shadows = @[
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.4f] offset:CGSizeMake(1.0f, 0.0f) blur:0.0f],
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.07f] offset:CGSizeMake(-1.0f, 0.0f) blur:0.0f]
    ];

    LGTabBarSegmentStyle *compactSelectedSegment = [[LGTabBarSegmentStyle alloc] init];
    compactSelectedSegment.colors = selectedSegmentColors;
    compactSelectedSegment.locations = segmentLocations;
    compactSelectedSegment.shadows = selectedSegmentShadows;

    LGTabBarLayout *compactLayout = [[LGTabBarLayout alloc] init];
    compactLayout.segmentStyle = compactSegment;
    compactLayout.selectedSegmentStyle = compactSelectedSegment;
    compactLayout.iconTopInset = 5.0f;
    compactLayout.titleBottomInset = 2.0f;
    compactLayout.titleHeight = 12.0f;
    appearance.compactLayout = compactLayout;

    LGTabBarSegmentStyle *regularSegment = [[LGTabBarSegmentStyle alloc] init];
    regularSegment.colors = segmentColors;
    regularSegment.locations = segmentLocations;
    regularSegment.shadows = @[
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.07f] offset:CGSizeMake(-1.0f, 0.0f) blur:0.0f],
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.9f] offset:CGSizeMake(0.0f, 1.0f) blur:0.0f],
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.15f] offset:CGSizeMake(0.0f, 1.5f) blur:0.0f],
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.1f] offset:CGSizeMake(0.0f, 2.0f) blur:0.0f]
    ];
    regularSegment.trailingEdgeColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
    regularSegment.trailingEdgeAboveNeighbor = YES;

    LGTabBarSegmentStyle *regularSelectedSegment = [[LGTabBarSegmentStyle alloc] init];
    regularSelectedSegment.colors = selectedSegmentColors;
    regularSelectedSegment.locations = segmentLocations;
    regularSelectedSegment.shadows = selectedSegmentShadows;
    regularSelectedSegment.trailingEdgeColor = [UIColor colorWithWhite:1.0f alpha:0.1f];
    regularSelectedSegment.trailingEdgeAboveNeighbor = NO;

    LGTabBarLayout *regularLayout = [[LGTabBarLayout alloc] init];
    regularLayout.segmentStyle = regularSegment;
    regularLayout.selectedSegmentStyle = regularSelectedSegment;
    regularLayout.iconTopInset = 4.0f;
    regularLayout.titleBottomInset = 4.0f;
    regularLayout.titleHeight = 12.0f;
    appearance.regularLayout = regularLayout;
    appearance.regularLayoutMinimumItemCount = 4;

    return appearance;
}

@end
