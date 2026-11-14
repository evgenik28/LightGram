#import "LGMenuSheetAppearance.h"
#import "LGSurfaceStyle.h"

static UIColor *LGMenuSheetRGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
    return [UIColor colorWithRed:red / 255.0f green:green / 255.0f blue:blue / 255.0f alpha:alpha];
}

static UIFont *LGMenuSheetFont(NSString *name, CGFloat size, BOOL bold)
{
    UIFont *font = [UIFont fontWithName:name size:size];
    if (font != nil)
        return font;
    return bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
}

@implementation LGMenuSheetAppearance

+ (LGMenuSheetAppearance *)brandedAppearanceDark:(BOOL)dark
{
    LGMenuSheetAppearance *appearance = [[LGMenuSheetAppearance alloc] init];
    UIColor *white = [UIColor whiteColor];
    UIColor *black = [UIColor blackColor];
    appearance.cornerRadius = 10.0f;
    appearance.buttonFont = LGMenuSheetFont(@"HelveticaNeue", 19.0f, NO);
    appearance.cancelButtonFont = LGMenuSheetFont(@"HelveticaNeue-Bold", 19.0f, YES);

    LGSurfaceStyle *surface = [[LGSurfaceStyle alloc] init];
    surface.textureResourceDirectory = @"ios6style";
    surface.shape = LGSurfaceShapeRoundedRect;
    surface.cornerRadius = appearance.cornerRadius;

    LGSurfaceLayer *sheen = [[LGSurfaceLayer alloc] init];
    sheen.locations = @[@0.0f, @1.0f];
    sheen.gradientAngle = 180.0f;

    if (dark)
    {
        surface.textureAssetName = @"blackpaper.jpg";
        surface.textureReferenceWidth = 320.0f;
        sheen.colors = @[[white colorWithAlphaComponent:0.06f], [black colorWithAlphaComponent:0.18f]];
        surface.shadows = @[
            [LGSurfaceShadow insetShadowWithColor:[white colorWithAlphaComponent:0.14f] offset:CGSizeMake(0.0f, 1.0f) blur:0.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.9f] offset:CGSizeZero blur:1.0f]
        ];
        appearance.backgroundColor = LGMenuSheetRGB(43.0f, 43.0f, 43.0f, 1.0f);
        appearance.selectionColor = [white colorWithAlphaComponent:0.08f];
        appearance.separatorColor = [black colorWithAlphaComponent:0.6f];
        appearance.accentColor = LGMenuSheetRGB(206.0f, 206.0f, 206.0f, 1.0f);
        appearance.destructiveColor = LGMenuSheetRGB(235.0f, 88.0f, 76.0f, 1.0f);
        appearance.textColor = LGMenuSheetRGB(206.0f, 206.0f, 206.0f, 1.0f);
        appearance.secondaryTextColor = LGMenuSheetRGB(150.0f, 150.0f, 150.0f, 1.0f);
        appearance.textShadowColor = [black colorWithAlphaComponent:0.8f];
        appearance.textShadowOffset = CGSizeMake(0.0f, -1.0f);
    }
    else
    {
        surface.textureAssetName = @"whitepaper.jpg";
        surface.textureReferenceWidth = 0.0f;
        sheen.colors = @[[white colorWithAlphaComponent:0.35f], [black colorWithAlphaComponent:0.05f]];
        surface.shadows = @[
            [LGSurfaceShadow insetShadowWithColor:[white colorWithAlphaComponent:0.9f] offset:CGSizeMake(0.0f, 1.0f) blur:0.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.35f] offset:CGSizeZero blur:1.0f]
        ];
        appearance.backgroundColor = LGMenuSheetRGB(245.0f, 244.0f, 241.0f, 1.0f);
        appearance.selectionColor = [black colorWithAlphaComponent:0.1f];
        appearance.separatorColor = [black colorWithAlphaComponent:0.16f];
        appearance.accentColor = LGMenuSheetRGB(56.0f, 84.0f, 135.0f, 1.0f);
        appearance.destructiveColor = LGMenuSheetRGB(204.0f, 42.0f, 36.0f, 1.0f);
        appearance.textColor = LGMenuSheetRGB(40.0f, 40.0f, 40.0f, 1.0f);
        appearance.secondaryTextColor = LGMenuSheetRGB(115.0f, 115.0f, 115.0f, 1.0f);
        appearance.textShadowColor = [white colorWithAlphaComponent:0.9f];
        appearance.textShadowOffset = CGSizeMake(0.0f, 1.0f);
    }
    surface.layers = @[sheen];
    appearance.surfaceStyle = surface;
    return appearance;
}

@end
