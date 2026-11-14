#import "LGDialogListAppearance.h"
#import "LGSurfaceStyle.h"

static UIColor *LGDialogListRGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
    return [UIColor colorWithRed:red / 255.0f green:green / 255.0f blue:blue / 255.0f alpha:alpha];
}

static UIFont *LGDialogListBoldFont(CGFloat size)
{
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:size];
    return font != nil ? font : [UIFont boldSystemFontOfSize:size];
}

static LGSurfaceStyle *LGDialogListTextureStyle(NSString *assetName, CGFloat referenceWidth)
{
    LGSurfaceStyle *style = [[LGSurfaceStyle alloc] init];
    style.textureResourceDirectory = @"ios6style";
    style.textureAssetName = assetName;
    style.textureReferenceWidth = referenceWidth;
    return style;
}

static LGSurfaceStyle *LGDialogListLeatherStyle(void)
{
    LGSurfaceStyle *style = LGDialogListTextureStyle(@"alcantara.png", 153.6f);
    style.textureTiled = YES;
    return style;
}

static LGSurfaceLayer *LGDialogListLinearLayer(UIEdgeInsets insets, NSArray *colors, CGFloat angle)
{
    LGSurfaceLayer *layer = [[LGSurfaceLayer alloc] init];
    layer.insets = insets;
    layer.colors = colors;
    layer.locations = @[@0.0f, @1.0f];
    layer.gradientAngle = angle;
    return layer;
}

@implementation LGDialogListAppearance

+ (LGDialogListAppearance *)brandedAppearanceDark:(BOOL)dark
{
    LGDialogListAppearance *appearance = [[LGDialogListAppearance alloc] init];
    UIColor *white = [UIColor whiteColor];
    UIColor *black = [UIColor blackColor];
    appearance.rowHeight = 65.0f;

    LGSurfaceStyle *avatarOverlay = [[LGSurfaceStyle alloc] init];
    avatarOverlay.shape = LGSurfaceShapeRoundedRect;
    avatarOverlay.cornerRadius = 8.0f;
    avatarOverlay.fillColor = [UIColor clearColor];
    appearance.avatarOverlaySurfaceStyle = avatarOverlay;

    appearance.actionFallbackColor = LGDialogListRGB(48.0f, 49.0f, 55.0f, 1.0f);
    UIFont *mentionFont = [UIFont fontWithName:@"HelveticaNeue" size:13.0f];
    appearance.mentionFont = mentionFont != nil ? mentionFont : [UIFont systemFontOfSize:13.0f];
    appearance.mentionOpticalSize = 11.27f;
    LGSurfaceShadow *mentionDropShadow = [LGSurfaceShadow dropShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f];
    appearance.folderButtonFont = LGDialogListBoldFont(12.0f);

    if (dark)
    {
        avatarOverlay.shadows = @[
            [LGSurfaceShadow insetShadowWithColor:LGDialogListRGB(255.0f, 253.0f, 253.0f, 0.3f) offset:CGSizeMake(0.0f, -1.0f) blur:0.5f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
        ];

        LGSurfaceStyle *cellBackground = [[LGSurfaceStyle alloc] init];
        cellBackground.shape = LGSurfaceShapeBand;
        cellBackground.fillColor = LGDialogListRGB(43.0f, 43.0f, 43.0f, 1.0f);
        cellBackground.shadows = @[[LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f]];
        appearance.cellBackgroundSurfaceStyle = cellBackground;

        appearance.messageColor = LGDialogListRGB(190.0f, 190.0f, 190.0f, 1.0f);
        appearance.messageUnreadColor = white;
        appearance.dateColor = LGDialogListRGB(185.0f, 185.0f, 185.0f, 1.0f);
        appearance.statusColor = LGDialogListRGB(185.0f, 185.0f, 185.0f, 1.0f);
        appearance.disclosureColor = LGDialogListRGB(185.0f, 185.0f, 185.0f, 1.0f);
        appearance.disclosureUnreadColor = white;
        appearance.pinGradientColors = @[white, LGDialogListRGB(197.0f, 197.0f, 197.0f, 1.0f)];
        appearance.mentionGradientColors = @[white, white];
        appearance.mentionGradientLocations = @[@0.0f, @1.0f];
        appearance.mentionShadows = @[mentionDropShadow];

        LGSurfaceStyle *action = LGDialogListTextureStyle(@"blackpaper.jpg", 320.0f);
        action.shape = LGSurfaceShapeBand;
        action.layers = @[LGDialogListLinearLayer(UIEdgeInsetsMake(0.0f, 74.0f, 0.0f, -74.0f), @[LGDialogListRGB(113.0f, 108.0f, 108.0f, 0.08f), LGDialogListRGB(11.0f, 10.0f, 10.0f, 0.64f)], 90.0f)];
        appearance.actionSurfaceStyle = action;

        LGSurfaceStyle *header = LGDialogListLeatherStyle();
        header.shape = LGSurfaceShapeBand;
        appearance.headerSurfaceStyle = header;
        appearance.folderTabsSeparatorColor = [UIColor clearColor];
        appearance.folderEmptyColor = LGDialogListRGB(155.0f, 155.0f, 155.0f, 1.0f);

        LGSurfaceStyle *folderButton = LGDialogListLeatherStyle();
        folderButton.shape = LGSurfaceShapeRoundedRect;
        folderButton.cornerRadius = 5.0f;
        folderButton.layers = @[LGDialogListLinearLayer(UIEdgeInsetsZero, @[[white colorWithAlphaComponent:0.1f], [black colorWithAlphaComponent:0.1f]], 180.0f)];
        folderButton.shadows = @[
            [LGSurfaceShadow dropShadowWithColor:[white colorWithAlphaComponent:0.1f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f],
            [LGSurfaceShadow insetShadowWithColor:black offset:CGSizeZero blur:1.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeZero blur:5.0f]
        ];
        appearance.folderButtonSurfaceStyle = folderButton;
        LGSurfaceStyle *pressedFolderButton = [folderButton copy];
        pressedFolderButton.overlayColor = [black colorWithAlphaComponent:0.25f];
        appearance.folderButtonPressedSurfaceStyle = pressedFolderButton;
        appearance.folderButtonTitleColor = LGDialogListRGB(206.0f, 206.0f, 206.0f, 1.0f);
        appearance.folderButtonHighlightedTitleColor = LGDialogListRGB(206.0f, 206.0f, 206.0f, 1.0f);
        appearance.folderButtonShadowColor = [black colorWithAlphaComponent:0.8f];
        appearance.folderButtonHighlightedShadowColor = [black colorWithAlphaComponent:0.8f];
        appearance.folderButtonShadowOffset = CGSizeMake(0.0f, -1.0f);
        appearance.folderButtonHeight = 29.0f;
        appearance.folderButtonMinimumWidth = 55.0f;
        appearance.folderButtonHorizontalPadding = 10.0f;
        appearance.folderButtonTitleBottomInset = 0.0f;
        appearance.folderTabsInset = 12.0f;
        appearance.folderTabsTrailingInset = 12.0f;
        appearance.folderTabsHeight = 36.0f;
        appearance.folderButtonTopInset = 0.0f;
        appearance.folderTabsSpacing = 6.0f;
        appearance.searchBarHeight = 41.0f;
        appearance.searchFieldInsets = UIEdgeInsetsMake(4.0f, 12.0f, 10.0f, 12.0f);
        appearance.navigationButtonHorizontalInset = 7.0f;
        appearance.navigationButtonVerticalOffset = 2.0f;
        appearance.navigationTitleVerticalOffset = 2.0f;

        LGSurfaceStyle *selectedFolderButton = [folderButton copy];
        selectedFolderButton.layers = @[LGDialogListLinearLayer(UIEdgeInsetsZero, @[[black colorWithAlphaComponent:0.3f], [black colorWithAlphaComponent:0.3f]], 180.0f)];
        appearance.folderButtonSelectedSurfaceStyle = selectedFolderButton;
    }
    else
    {
        avatarOverlay.shadows = @[
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f],
            [LGSurfaceShadow insetShadowWithColor:[white colorWithAlphaComponent:0.6f] offset:CGSizeMake(0.0f, -1.0f) blur:1.0f]
        ];

        appearance.messageColor = black;
        appearance.messageUnreadColor = LGDialogListRGB(134.0f, 130.0f, 130.0f, 1.0f);
        appearance.dateColor = LGDialogListRGB(89.0f, 89.0f, 89.0f, 1.0f);
        appearance.statusColor = LGDialogListRGB(90.0f, 90.0f, 90.0f, 1.0f);
        appearance.disclosureColor = black;
        appearance.disclosureUnreadColor = LGDialogListRGB(134.0f, 130.0f, 130.0f, 1.0f);
        appearance.pinGradientColors = @[[UIColor colorWithWhite:0.714f alpha:1.0f], [UIColor colorWithWhite:0.537f alpha:1.0f]];
        appearance.mentionGradientColors = @[LGDialogListRGB(163.0f, 163.0f, 163.0f, 1.0f), LGDialogListRGB(61.0f, 61.0f, 61.0f, 1.0f)];
        appearance.mentionGradientLocations = @[@0.0f, @1.6925f];
        appearance.mentionShadows = @[
            mentionDropShadow,
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
        ];
        appearance.actionPatternAssetName = @"cloth";

        LGSurfaceStyle *folderTabsHeader = [[LGSurfaceStyle alloc] init];
        folderTabsHeader.shape = LGSurfaceShapeBand;
        folderTabsHeader.fillColor = LGDialogListRGB(224.0f, 224.0f, 224.0f, 1.0f);
        folderTabsHeader.shadows = @[[LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f]];
        appearance.headerSurfaceStyle = folderTabsHeader;
        appearance.headerColor = LGDialogListRGB(224.0f, 224.0f, 224.0f, 1.0f);
        appearance.folderTabsSeparatorColor = [UIColor clearColor];
        appearance.folderEmptyColor = LGDialogListRGB(122.0f, 122.0f, 122.0f, 1.0f);

        NSArray *folderButtonShadows = @[
            [LGSurfaceShadow dropShadowWithColor:[white colorWithAlphaComponent:0.4f] offset:CGSizeMake(0.0f, 0.5f) blur:0.5f],
            [LGSurfaceShadow insetShadowWithColor:black offset:CGSizeZero blur:1.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
        ];
        LGSurfaceStyle *folderButton = [[LGSurfaceStyle alloc] init];
        folderButton.shape = LGSurfaceShapeRoundedRect;
        folderButton.cornerRadius = 12.0f;
        folderButton.fillColor = [black colorWithAlphaComponent:0.3f];
        folderButton.shadows = folderButtonShadows;
        appearance.folderButtonSurfaceStyle = folderButton;
        LGSurfaceStyle *pressedFolderButton = [folderButton copy];
        pressedFolderButton.overlayColor = [black colorWithAlphaComponent:0.25f];
        appearance.folderButtonPressedSurfaceStyle = pressedFolderButton;
        appearance.folderButtonTitleColor = white;
        appearance.folderButtonHighlightedTitleColor = white;
        appearance.folderButtonShadowColor = [black colorWithAlphaComponent:0.25f];
        appearance.folderButtonHighlightedShadowColor = [black colorWithAlphaComponent:0.25f];
        appearance.folderButtonShadowOffset = CGSizeMake(0.0f, -1.0f);
        appearance.folderButtonHeight = 23.0f;
        appearance.folderButtonMinimumWidth = 41.0f;
        appearance.folderButtonHorizontalPadding = 10.0f;
        appearance.folderButtonTitleBottomInset = 0.0f;
        appearance.folderTabsInset = 12.0f;
        appearance.folderTabsTrailingInset = 14.0f;
        appearance.folderTabsHeight = 32.0f;
        appearance.folderButtonTopInset = 5.0f;
        appearance.folderTabsSpacing = 18.0f;
        appearance.searchBarHeight = 40.0f;
        appearance.searchFieldInsets = UIEdgeInsetsZero;

        LGSurfaceStyle *selectedFolderButton = [folderButton copy];
        selectedFolderButton.fillColor = [black colorWithAlphaComponent:0.6f];
        appearance.folderButtonSelectedSurfaceStyle = selectedFolderButton;
    }
    if (appearance.folderButtonSelectedSurfaceStyle != nil)
    {
        LGSurfaceStyle *pressedSelectedFolderButton = [appearance.folderButtonSelectedSurfaceStyle copy];
        pressedSelectedFolderButton.overlayColor = [black colorWithAlphaComponent:0.25f];
        appearance.folderButtonSelectedPressedSurfaceStyle = pressedSelectedFolderButton;
    }
    return appearance;
}

@end
