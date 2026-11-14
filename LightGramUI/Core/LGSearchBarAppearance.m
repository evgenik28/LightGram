#import "LGSearchBarAppearance.h"
#import "LGSurfaceStyle.h"

static UIColor *LGSearchBarRGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
    return [UIColor colorWithRed:red / 255.0f green:green / 255.0f blue:blue / 255.0f alpha:alpha];
}

static LGSurfaceStyle *LGSearchBarTextureStyle(NSString *assetName, CGFloat referenceWidth)
{
    LGSurfaceStyle *style = [[LGSurfaceStyle alloc] init];
    style.textureResourceDirectory = @"ios6style";
    style.textureAssetName = assetName;
    style.textureReferenceWidth = referenceWidth;
    return style;
}

@implementation LGSearchBarAppearance

+ (LGSearchBarAppearance *)contactAppearanceDark:(BOOL)dark
{
    LGSearchBarAppearance *appearance = [self brandedAppearanceDark:NO];
    UIColor *bandColor = dark ? LGSearchBarRGB(53.0f, 53.0f, 53.0f, 1.0f) : appearance.backdropColor;
    appearance.backgroundSurfaceStyle.fillColor = bandColor;
    appearance.backgroundSurfaceStyle.shadows = @[
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.2f] offset:CGSizeMake(0.0f, 0.5f) blur:0.0f],
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.2f] offset:CGSizeMake(0.0f, 1.0f) blur:0.0f],
        [LGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:dark ? 0.7f : 0.1f] offset:CGSizeMake(0.0f, -1.0f) blur:0.0f]
    ];
    appearance.backdropColor = bandColor;
    appearance.textColor = [UIColor blackColor];
    return appearance;
}

+ (LGSearchBarAppearance *)brandedAppearanceDark:(BOOL)dark
{
    LGSearchBarAppearance *appearance = [[LGSearchBarAppearance alloc] init];
    UIColor *white = [UIColor whiteColor];
    UIColor *black = [UIColor blackColor];

    LGSurfaceStyle *background = nil;
    LGSurfaceStyle *field = nil;
    if (dark)
    {
        background = LGSearchBarTextureStyle(@"alcantara.png", 165.0f);
        background.textureTiled = YES;

        field = LGSearchBarTextureStyle(@"list", 320.0f);
        field.textureContrast = 2.0f;
        field.textureBias = -1.0094f;
        field.shadows = @[
            [LGSurfaceShadow dropShadowWithColor:[white colorWithAlphaComponent:0.1f] offset:CGSizeMake(0.0f, 1.5f) blur:1.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.2f] offset:CGSizeZero blur:0.0f spread:1.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.2f] offset:CGSizeMake(0.0f, 1.0f) blur:3.0f spread:2.0f]
        ];

        appearance.textColor = black;
        appearance.placeholderColor = LGSearchBarRGB(162.0f, 162.0f, 162.0f, 1.0f);
        appearance.iconColor = LGSearchBarRGB(115.0f, 115.0f, 115.0f, 1.0f);
        appearance.iconSize = 14.0f;
        appearance.iconCircleDiameter = 12.0f;
        appearance.iconLineWidth = 2.0f;
        appearance.iconOffset = UIOffsetMake(10.0f, 0.0f);
        appearance.placeholderOffset = UIOffsetMake(31.0f, 0.0f);
    }
    else
    {
        UIColor *bandColor = LGSearchBarRGB(224.0f, 224.0f, 224.0f, 1.0f);
        background = [[LGSurfaceStyle alloc] init];
        background.fillColor = bandColor;
        background.shadows = @[
            [LGSurfaceShadow insetShadowWithColor:[white colorWithAlphaComponent:0.2f] offset:CGSizeMake(0.0f, 0.5f) blur:0.0f],
            [LGSurfaceShadow insetShadowWithColor:[white colorWithAlphaComponent:0.2f] offset:CGSizeMake(0.0f, 1.0f) blur:0.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.1f] offset:CGSizeMake(0.0f, -1.0f) blur:0.0f]
        ];

        field = [[LGSurfaceStyle alloc] init];
        field.fillColor = white;
        field.shadows = @[
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.5f] offset:CGSizeMake(0.0f, 2.0f) blur:3.0f]
        ];
        field.strokeWidth = 1.0f;
        field.strokeColors = @[LGSearchBarRGB(125.0f, 143.0f, 164.0f, 1.0f), LGSearchBarRGB(161.0f, 174.0f, 185.0f, 1.0f)];

        appearance.backdropColor = bandColor;
        appearance.placeholderColor = LGSearchBarRGB(178.0f, 178.0f, 178.0f, 1.0f);
        appearance.iconColor = LGSearchBarRGB(147.0f, 152.0f, 158.0f, 1.0f);
        appearance.iconSize = 14.0f;
        appearance.iconCircleDiameter = 12.0f;
        appearance.iconLineWidth = 2.0f;
        appearance.iconOffset = UIOffsetMake(10.0f, 0.0f);
        appearance.placeholderOffset = UIOffsetMake(31.0f, 1.0f);
    }
    background.shape = LGSurfaceShapeBand;
    field.shape = LGSurfaceShapeRoundedRect;
    field.cornerRadius = 15.0f;
    appearance.backgroundSurfaceStyle = background;
    appearance.fieldSurfaceStyle = field;
    return appearance;
}

@end
