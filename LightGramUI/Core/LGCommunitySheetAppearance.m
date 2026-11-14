#import "LGCommunitySheetAppearance.h"
#import "LGNavigationAppearance.h"
#import "LGSurfaceStyle.h"

@implementation LGCommunitySheetAppearance

+ (LGCommunitySheetAppearance *)brandedAppearanceDark:(BOOL)dark navigationAppearance:(LGNavigationAppearance *)navigationAppearance
{
    LGCommunitySheetAppearance *appearance = [[LGCommunitySheetAppearance alloc] init];
    appearance.dimColor = [UIColor colorWithWhite:0.0f alpha:0.6f];
    appearance.collapsedHeightFraction = dark ? 335.0f / 568.0f : 277.0f / 568.0f;
    appearance.headerHeight = 44.0f;

    LGSurfaceStyle *header = [navigationAppearance.backgroundSurfaceStyle copy];
    header.shape = LGSurfaceShapeSheet;
    header.cornerRadius = 7.0f;
    NSMutableArray *insetShadows = [[NSMutableArray alloc] init];
    for (LGSurfaceShadow *shadow in header.shadows)
    {
        if (shadow.inset)
            [insetShadows addObject:shadow];
    }
    header.shadows = insetShadows;
    appearance.headerSurfaceStyle = header;

    appearance.indicatorColor = [UIColor whiteColor];
    appearance.indicatorSpacing = 17.0f;
    return appearance;
}

@end
