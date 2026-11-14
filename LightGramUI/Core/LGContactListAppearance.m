#import "LGContactListAppearance.h"
#import "LGSurfaceStyle.h"
#import "LGSearchBarAppearance.h"

static UIColor *LGContactListRGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
    return [UIColor colorWithRed:red / 255.0f green:green / 255.0f blue:blue / 255.0f alpha:alpha];
}

static UIFont *LGContactListBoldFont(CGFloat size)
{
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:size];
    return font != nil ? font : [UIFont boldSystemFontOfSize:size];
}

@implementation LGContactListAppearance

+ (LGContactListAppearance *)brandedAppearanceDark:(BOOL)dark
{
    LGContactListAppearance *appearance = [[LGContactListAppearance alloc] init];
    UIColor *white = [UIColor whiteColor];
    UIColor *black = [UIColor blackColor];

    appearance.rowHeight = 44.0f;
    appearance.rowTitleFont = [UIFont fontWithName:@"HelveticaNeue" size:20.0f] ?: [UIFont systemFontOfSize:20.0f];
    appearance.rowTitleBoldFont = LGContactListBoldFont(20.0f);
    appearance.rowTitleRightInset = 24.0f;
    appearance.searchBarAppearance = [LGSearchBarAppearance contactAppearanceDark:dark];
    appearance.sectionHeaderHeight = 24.0f;
    appearance.searchBarOverlap = 1.0f;
    appearance.sectionTitleFont = LGContactListBoldFont(18.0f);
    appearance.sectionTitleLeftInset = 12.0f;
    appearance.sectionTitleBottomInset = 2.0f;
    appearance.searchFieldInsets = UIEdgeInsetsMake(7.0f, 5.0f, 7.0f, 8.0f);
    appearance.searchIndexInset = 24.0f;
    appearance.showsSectionIndex = NO;

    LGSurfaceLayer *gradient = [[LGSurfaceLayer alloc] init];
    gradient.colors = dark ? @[LGContactListRGB(53.0f, 53.0f, 53.0f, 1.0f), LGContactListRGB(21.0f, 21.0f, 21.0f, 1.0f)] : @[LGContactListRGB(224.0f, 224.0f, 224.0f, 0.18f), LGContactListRGB(203.0f, 203.0f, 203.0f, 0.18f)];
    gradient.locations = @[@0.0f, @1.0f];
    gradient.gradientAngle = 180.0f;

    LGSurfaceStyle *header = [[LGSurfaceStyle alloc] init];
    header.shape = LGSurfaceShapeBand;
    header.fillColor = white;
    header.layers = @[gradient];
    header.shadows = @[
        [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.1f] offset:CGSizeMake(0.0f, 0.5f) blur:0.0f],
        [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.15f] offset:CGSizeMake(0.0f, 1.0f) blur:0.0f],
        [LGSurfaceShadow insetShadowWithColor:[white colorWithAlphaComponent:0.1f] offset:CGSizeMake(0.0f, 1.5f) blur:0.0f],
        [LGSurfaceShadow insetShadowWithColor:[white colorWithAlphaComponent:0.15f] offset:CGSizeMake(0.0f, 2.0f) blur:0.0f],
        [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.05f] offset:CGSizeMake(0.0f, -0.5f) blur:0.0f],
        [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.1f] offset:CGSizeMake(0.0f, -1.0f) blur:0.0f]
    ];
    appearance.sectionHeaderSurfaceStyle = header;
    appearance.sectionTitleColor = dark ? white : black;
    appearance.sectionTitleShadowColor = [black colorWithAlphaComponent:0.4f];
    appearance.sectionTitleShadowOffset = CGSizeMake(0.0f, 1.0f);
    appearance.separatorColor = [black colorWithAlphaComponent:0.12f];
    appearance.separatorHeight = 1.0f;
    appearance.hidesSeparatorAboveSectionHeader = YES;
    appearance.indexColor = LGContactListRGB(111.0f, 120.0f, 131.0f, 1.0f);
    appearance.indexTrackingBackgroundColor = LGContactListRGB(244.0f, 244.0f, 244.0f, 1.0f);

    if (dark)
    {
        appearance.rowBackgroundColor = LGContactListRGB(53.0f, 53.0f, 53.0f, 1.0f);
        appearance.rowTitleColor = white;
        LGSurfaceStyle *navigation = [[LGSurfaceStyle alloc] init];
        navigation.shape = LGSurfaceShapeBand;
        navigation.textureResourceDirectory = @"ios6style";
        navigation.textureAssetName = @"leather.jpg";
        navigation.textureReferenceWidth = 320.0f;
        LGSurfaceLayer *gloss = [[LGSurfaceLayer alloc] init];
        gloss.colors = @[[white colorWithAlphaComponent:0.1f], [white colorWithAlphaComponent:0.0f]];
        gloss.locations = @[@0.0f, @1.0f];
        navigation.layers = @[gloss];
        appearance.navigationSurfaceStyle = navigation;
        appearance.navigationStitchColor = LGContactListRGB(104.0f, 104.0f, 104.0f, 0.7f);
    }
    return appearance;
}

@end
