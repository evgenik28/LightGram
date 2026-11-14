#import "LGConversationAppearance.h"
#import "LGSurfaceStyle.h"

static UIColor *LGConversationRGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
    return [UIColor colorWithRed:red / 255.0f green:green / 255.0f blue:blue / 255.0f alpha:alpha];
}

static UIFont *LGConversationFont(NSString *name, CGFloat size, BOOL bold)
{
    UIFont *font = [UIFont fontWithName:name size:size];
    if (font != nil)
        return font;
    return bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
}

static LGSurfaceLayer *LGConversationLayer(UIEdgeInsets insets, CGFloat width, CGFloat height, BOOL right, BOOL bottom, CGFloat cornerRadius, NSArray *colors, NSArray *locations, CGFloat angle, LGSurfaceBlendMode blendMode, NSArray *shadows)
{
    LGSurfaceLayer *layer = [[LGSurfaceLayer alloc] init];
    layer.insets = insets;
    layer.width = width;
    layer.height = height;
    layer.anchoredToRight = right;
    layer.anchoredToBottom = bottom;
    layer.cornerRadius = cornerRadius;
    layer.colors = colors;
    layer.locations = locations;
    layer.gradientAngle = angle;
    layer.blendMode = blendMode;
    layer.shadows = shadows;
    return layer;
}

static LGSurfaceStyle *LGConversationTextureStyle(NSString *assetName, CGFloat referenceWidth, BOOL tiled)
{
    LGSurfaceStyle *style = [[LGSurfaceStyle alloc] init];
    style.textureResourceDirectory = @"ios6style";
    style.textureAssetName = assetName;
    style.textureReferenceWidth = referenceWidth;
    style.textureTiled = tiled;
    return style;
}

static LGSurfaceStyle *LGConversationLeatherStyle(void)
{
    return LGConversationTextureStyle(@"alcantara.png", 165.0f, YES);
}

static LGSurfaceStyle *LGConversationPaperStyle(void)
{
    LGSurfaceStyle *style = LGConversationTextureStyle(@"list", 320.0f, NO);
    style.textureContrast = 2.0f;
    style.textureBias = -1.0094f;
    return style;
}

static LGSurfaceStyle *LGConversationBubbleStyle(BOOL outgoing, BOOL dark, BOOL voice)
{
    UIColor *white = [UIColor whiteColor];
    CGFloat edgeAlpha = outgoing && !voice ? 0.6f : 1.0f;

    LGSurfaceStyle *style = [[LGSurfaceStyle alloc] init];
    style.shape = outgoing ? LGSurfaceShapeBubbleRight : LGSurfaceShapeBubbleLeft;
    style.cornerRadius = 13.0f;
    style.tailSize = CGSizeMake(13.0f, 12.0f);
    style.tailBottomInset = 1.0f;
    if (voice)
    {
        style.fillColor = LGConversationRGB(221.0f, 221.0f, 221.0f, 1.0f);
        style.opacity = 1.0f;
    }
    else if (outgoing && dark)
    {
        style.fillColor = LGConversationRGB(149.0f, 170.0f, 195.0f, 0.8f);
        style.opacity = 1.0f;
    }
    else
    {
        style.fillColor = outgoing ? LGConversationRGB(152.0f, 199.0f, 255.0f, 1.0f) : LGConversationRGB(221.0f, 221.0f, 221.0f, 1.0f);
        style.opacity = 0.8f;
    }

    LGSurfaceLayer *shade = LGConversationLayer(outgoing ? UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, -7.0f) : UIEdgeInsetsMake(0.0f, -7.0f, 0.0f, 0.0f), 0.0f, 13.0f, NO, YES, 0.0f, @[[white colorWithAlphaComponent:0.0f], [white colorWithAlphaComponent:edgeAlpha]], @[@0.0f, @1.0f], 180.0f, LGSurfaceBlendModeSoftLight, @[]);
    LGSurfaceLayer *light = LGConversationLayer(outgoing ? UIEdgeInsetsMake(0.0f, 0.0f, 1.34f, -5.9f) : UIEdgeInsetsMake(0.0f, -5.9f, 1.34f, 0.0f), 8.9f, 8.66f, outgoing, YES, 0.0f, @[[white colorWithAlphaComponent:0.0f], [white colorWithAlphaComponent:edgeAlpha]], @[@0.1909f, @1.0222f], outgoing ? 122.19f : 237.81f, LGSurfaceBlendModeHardLight, @[]);
    LGSurfaceLayer *gloss = LGConversationLayer(UIEdgeInsetsMake(0.0f, 7.0f, 0.0f, 7.0f), 0.0f, 13.0f, NO, NO, 7.0f, @[[white colorWithAlphaComponent:0.75f], [white colorWithAlphaComponent:0.25f]], @[@0.0f, @1.0f], 180.0f, LGSurfaceBlendModeNormal, @[[LGSurfaceShadow insetShadowWithColor:[white colorWithAlphaComponent:0.8f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]]);
    style.layers = @[shade, light, gloss];

    UIColor *black = [UIColor blackColor];
    style.shadows = @[
        [LGSurfaceShadow insetShadowWithColor:black offset:CGSizeZero blur:1.0f],
        [LGSurfaceShadow insetShadowWithColor:black offset:CGSizeZero blur:1.0f],
        [LGSurfaceShadow insetShadowWithColor:black offset:CGSizeZero blur:1.0f],
        [LGSurfaceShadow dropShadowWithColor:[black colorWithAlphaComponent:0.2f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f],
        [LGSurfaceShadow dropShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeZero blur:1.0f]
    ];
    return style;
}

static LGSurfaceLayer *LGConversationRoundGlossLayer(NSArray *colors, BOOL roundGloss)
{
    if (!roundGloss)
        return LGConversationLayer(UIEdgeInsetsZero, 0.0f, 13.0f, NO, NO, 0.0f, colors, @[@0.0f, @1.0f], 180.0f, LGSurfaceBlendModeNormal, @[]);
    LGSurfaceLayer *layer = LGConversationLayer(UIEdgeInsetsMake(1.0f, 3.0f, 0.0f, 3.0f), 0.0f, 13.0f, NO, NO, 0.0f, colors, @[@0.0f, @1.0f], 180.0f, LGSurfaceBlendModeNormal, @[]);
    layer.elliptical = YES;
    return layer;
}

static LGSurfaceStyle *LGConversationRoundButtonStyle(BOOL dark, BOOL roundGloss)
{
    UIColor *white = [UIColor whiteColor];
    UIColor *black = [UIColor blackColor];
    LGSurfaceStyle *style = [[LGSurfaceStyle alloc] init];
    if (dark)
    {
        style.layers = @[
            LGConversationLayer(UIEdgeInsetsZero, 0.0f, 0.0f, NO, NO, 0.0f, @[[white colorWithAlphaComponent:0.1f], [black colorWithAlphaComponent:0.1f]], @[@0.0f, @1.0f], 180.0f, LGSurfaceBlendModeNormal, @[]),
            LGConversationRoundGlossLayer(@[[white colorWithAlphaComponent:0.3f], [white colorWithAlphaComponent:0.1f]], roundGloss)
        ];
        style.shadows = @[
            [LGSurfaceShadow dropShadowWithColor:[white colorWithAlphaComponent:0.1f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f],
            [LGSurfaceShadow insetShadowWithColor:black offset:CGSizeZero blur:1.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeZero blur:5.0f]
        ];
    }
    else
    {
        style.fillColor = LGConversationRGB(99.0f, 111.0f, 131.0f, 1.0f);
        style.layers = @[LGConversationRoundGlossLayer(@[[white colorWithAlphaComponent:0.6f], [white colorWithAlphaComponent:0.2f]], roundGloss)];
        style.shadows = @[
            [LGSurfaceShadow dropShadowWithColor:[white colorWithAlphaComponent:0.6f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeZero blur:0.0f spread:1.0f]
        ];
    }
    style.shape = LGSurfaceShapeRoundedRect;
    style.cornerRadius = 13.0f;
    return style;
}

@implementation LGConversationAppearance

+ (LGConversationAppearance *)brandedAppearanceDark:(BOOL)dark
{
    LGConversationAppearance *appearance = [[LGConversationAppearance alloc] init];
    UIColor *white = [UIColor whiteColor];
    UIColor *black = [UIColor blackColor];

    if (dark)
    {
        LGSurfaceStyle *background = LGConversationLeatherStyle();
        background.shape = LGSurfaceShapeBand;
        appearance.backgroundSurfaceStyle = background;

        LGSurfaceStyle *card = LGConversationPaperStyle();
        card.shape = LGSurfaceShapeRoundedRect;
        card.cornerRadius = 13.0f;
        card.shadows = @[
            [LGSurfaceShadow dropShadowWithColor:[white colorWithAlphaComponent:0.1f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f]
        ];
        appearance.backgroundCardSurfaceStyle = card;
        appearance.backgroundCardHorizontalInset = 7.0f;
    }
    else
    {
        LGSurfaceStyle *background = LGConversationTextureStyle(@"list", 320.0f, NO);
        background.shape = LGSurfaceShapeBand;
        background.textureContrast = 0.35f;
        background.textureTintColor = LGConversationRGB(153.0f, 161.0f, 169.0f, 1.0f);
        appearance.backgroundSurfaceStyle = background;
    }

    appearance.outgoingBubbleSurfaceStyle = LGConversationBubbleStyle(YES, dark, NO);
    appearance.incomingBubbleSurfaceStyle = LGConversationBubbleStyle(NO, dark, NO);
    LGSurfaceStyle *outgoingHighlighted = [appearance.outgoingBubbleSurfaceStyle copy];
    outgoingHighlighted.overlayColor = [black colorWithAlphaComponent:0.15f];
    appearance.outgoingHighlightedBubbleSurfaceStyle = outgoingHighlighted;
    LGSurfaceStyle *incomingHighlighted = [appearance.incomingBubbleSurfaceStyle copy];
    incomingHighlighted.overlayColor = [black colorWithAlphaComponent:0.15f];
    appearance.incomingHighlightedBubbleSurfaceStyle = incomingHighlighted;
    LGSurfaceStyle *voiceIncoming = LGConversationBubbleStyle(NO, dark, YES);
    appearance.voiceIncomingBubbleSurfaceStyle = voiceIncoming;
    LGSurfaceStyle *voiceIncomingHighlighted = [voiceIncoming copy];
    voiceIncomingHighlighted.overlayColor = [black colorWithAlphaComponent:0.15f];
    appearance.voiceIncomingHighlightedBubbleSurfaceStyle = voiceIncomingHighlighted;
    LGSurfaceStyle *voiceOutgoing = LGConversationBubbleStyle(YES, dark, YES);
    appearance.voiceOutgoingBubbleSurfaceStyle = voiceOutgoing;
    LGSurfaceStyle *voiceOutgoingHighlighted = [voiceOutgoing copy];
    voiceOutgoingHighlighted.overlayColor = [black colorWithAlphaComponent:0.15f];
    appearance.voiceOutgoingHighlightedBubbleSurfaceStyle = voiceOutgoingHighlighted;

    appearance.bubbleImageBodySize = CGSizeMake(29.0f, 29.0f);
    appearance.outgoingBubbleImageInsets = UIEdgeInsetsMake(2.0f, 2.0f, 3.0f, 8.0f);
    appearance.incomingBubbleImageInsets = UIEdgeInsetsMake(2.0f, 8.0f, 3.0f, 2.0f);
    appearance.bubbleContentPadding = UIEdgeInsetsMake(2.0f, 10.0f, 4.0f, 10.0f);
    appearance.bubbleTimeRowHeight = 12.0f;
    appearance.bubbleTimeTrailingInset = 9.0f;
    appearance.messageFont = LGConversationFont(@"HelveticaNeue", 16.0f, NO);
    appearance.messageTextColor = [black colorWithAlphaComponent:0.8f];
    appearance.messageShadowColor = [white colorWithAlphaComponent:0.8f];
    appearance.messageShadowOffset = CGSizeMake(0.0f, 0.5f);
    appearance.timeFont = LGConversationFont(@"HelveticaNeue", 10.0f, NO);
    appearance.timeColor = LGConversationRGB(89.0f, 89.0f, 89.0f, 0.8f);
    appearance.voiceBubbleBodySize = CGSizeMake(154.0f, 41.0f);
    appearance.voiceButtonFrame = CGRectMake(5.0f, 5.0f, 20.0f, 20.0f);
    appearance.voiceWaveformFrame = CGRectMake(30.0f, 4.0f, 95.0f, 24.0f);
    appearance.voiceDurationFrame = CGRectMake(120.0f, 10.0f, 34.0f, 8.0f);
    appearance.voiceDurationFont = LGConversationFont(@"HelveticaNeue", 7.0f, NO);
    LGSurfaceStyle *voiceBar = [[LGSurfaceStyle alloc] init];
    voiceBar.shape = LGSurfaceShapeRoundedRect;
    voiceBar.cornerRadius = 1.5f;
    voiceBar.fillColor = LGConversationRGB(163.0f, 163.0f, 163.0f, 1.0f);
    voiceBar.shadows = @[[LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f]];
    appearance.voiceWaveformBarSurfaceStyle = voiceBar;
    LGSurfaceStyle *voicePlayedBar = [voiceBar copy];
    voicePlayedBar.fillColor = LGConversationRGB(113.0f, 113.0f, 113.0f, 1.0f);
    appearance.voiceWaveformPlayedBarSurfaceStyle = voicePlayedBar;
    LGSurfaceStyle *voiceButton = [[LGSurfaceStyle alloc] init];
    voiceButton.shape = LGSurfaceShapeRoundedRect;
    voiceButton.cornerRadius = 10.0f;
    voiceButton.layers = @[LGConversationLayer(UIEdgeInsetsZero, 0.0f, 0.0f, NO, NO, 0.0f, @[white, LGConversationRGB(39.0f, 138.0f, 242.0f, 1.0f), LGConversationRGB(62.0f, 201.0f, 251.0f, 1.0f)], @[@0.0f, @0.4904f, @1.0f], 180.0f, LGSurfaceBlendModeNormal, @[])];
    voiceButton.shadows = @[[LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]];
    appearance.voiceButtonSurfaceStyle = voiceButton;
    appearance.viewsIconAssetName = @"eye-fill-10";
    appearance.viewsIconSpacing = 3.0f;

    LGSurfaceStyle *panel = dark ? LGConversationLeatherStyle() : [[LGSurfaceStyle alloc] init];
    panel.shape = LGSurfaceShapeBand;
    if (!dark)
    {
        panel.layers = @[LGConversationLayer(UIEdgeInsetsZero, 0.0f, 0.0f, NO, NO, 0.0f, @[LGConversationRGB(239.0f, 240.0f, 241.0f, 1.0f), LGConversationRGB(197.0f, 199.0f, 203.0f, 1.0f)], @[@0.0f, @1.0f], 180.0f, LGSurfaceBlendModeNormal, @[])];
        panel.shadows = @[
            [LGSurfaceShadow dropShadowWithColor:[black colorWithAlphaComponent:0.1f] offset:CGSizeMake(0.0f, -1.0f) blur:1.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.2f] offset:CGSizeMake(0.0f, 0.5f) blur:0.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.2f] offset:CGSizeMake(0.0f, 1.0f) blur:0.0f],
            [LGSurfaceShadow insetShadowWithColor:[white colorWithAlphaComponent:0.8f] offset:CGSizeMake(0.0f, 1.5f) blur:0.0f],
            [LGSurfaceShadow insetShadowWithColor:[white colorWithAlphaComponent:0.2f] offset:CGSizeMake(0.0f, 2.0f) blur:0.0f]
        ];
    }
    appearance.inputPanelSurfaceStyle = panel;

    appearance.inputButtonSurfaceStyle = LGConversationRoundButtonStyle(dark, YES);

    LGSurfaceStyle *field = dark ? LGConversationPaperStyle() : [[LGSurfaceStyle alloc] init];
    field.shape = LGSurfaceShapeRoundedRect;
    field.cornerRadius = 13.0f;
    if (dark)
    {
        field.shadows = @[
            [LGSurfaceShadow dropShadowWithColor:[white colorWithAlphaComponent:0.1f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeMake(0.0f, 1.0f) blur:0.0f]
        ];
    }
    else
    {
        field.fillColor = LGConversationRGB(245.0f, 245.0f, 245.0f, 1.0f);
        field.shadows = @[
            [LGSurfaceShadow dropShadowWithColor:[white colorWithAlphaComponent:0.6f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f],
            [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.5f] offset:CGSizeMake(0.0f, 1.0f) blur:3.0f spread:1.0f]
        ];
    }
    appearance.inputFieldSurfaceStyle = field;

    appearance.inputButtonSize = 26.0f;
    appearance.inputFieldHeight = 26.0f;
    if (dark)
    {
        appearance.inputPanelPadding = UIEdgeInsetsMake(5.0f, 13.0f, 5.0f, 7.0f);
        appearance.inputPanelExtensionColor = LGConversationRGB(52.0f, 52.0f, 52.0f, 1.0f);
        appearance.inputFieldInsets = UIEdgeInsetsMake(5.0f, 47.0f, 5.0f, 40.0f);
        appearance.inputFieldPlaceholderColor = LGConversationRGB(173.0f, 173.0f, 173.0f, 1.0f);
    }
    else
    {
        appearance.inputPanelPadding = UIEdgeInsetsMake(5.0f, 6.0f, 5.0f, 6.0f);
        appearance.inputPanelExtensionColor = LGConversationRGB(197.0f, 199.0f, 203.0f, 1.0f);
        appearance.inputFieldInsets = UIEdgeInsetsMake(5.0f, 39.0f, 5.0f, 38.0f);
        appearance.inputFieldPlaceholderColor = LGConversationRGB(171.0f, 171.0f, 171.0f, 1.0f);
    }
    appearance.inputPanelHeight = appearance.inputFieldHeight + appearance.inputFieldInsets.top + appearance.inputFieldInsets.bottom;
    appearance.inputFieldTextInsets = UIEdgeInsetsMake(3.0f, 10.0f, 3.0f, 10.0f);
    appearance.inputFieldFont = LGConversationFont(@"HelveticaNeue", 16.0f, NO);
    appearance.inputFieldTextColor = black;
    appearance.inputButtonIconColor = white;
    appearance.inputButtonGlyphScale = 0.65f;
    appearance.inputButtonGlyphLineWidth = 1.75f;
    appearance.inputAttachGlyphShadow = [LGSurfaceShadow dropShadowWithColor:[black colorWithAlphaComponent:0.25f] offset:CGSizeMake(-1.0f, 1.0f) blur:0.0f];
    appearance.inputSendGlyphShadow = [LGSurfaceShadow dropShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, -1.0f) blur:1.0f];

    appearance.actionPanelHeight = dark ? 46.0f : 52.0f;
    appearance.actionButtonSurfaceStyle = LGConversationRoundButtonStyle(dark, NO);
    LGSurfaceStyle *actionButtonHighlighted = [appearance.actionButtonSurfaceStyle copy];
    actionButtonHighlighted.overlayColor = [black colorWithAlphaComponent:0.25f];
    appearance.actionButtonHighlightedSurfaceStyle = actionButtonHighlighted;
    appearance.actionButtonHeight = 32.0f;
    appearance.actionButtonSpacing = 13.0f;
    appearance.actionButtonMinimumWidth = 156.0f;
    appearance.actionIconButtonWidth = 34.0f;
    appearance.actionButtonContentInset = 16.0f;
    appearance.actionButtonIconSpacing = 6.0f;
    appearance.actionButtonFont = LGConversationFont(@"HelveticaNeue-Bold", 16.0f, YES);
    appearance.actionButtonTitleColor = white;
    appearance.actionButtonTitleShadowColor = [black colorWithAlphaComponent:0.4f];
    appearance.actionButtonTitleShadowOffset = CGSizeMake(0.0f, -1.0f);
    appearance.actionButtonIconColors = @[white, white];
    appearance.actionButtonIconLocations = @[@0.0f, @1.0f];
    appearance.actionButtonIconShadow = [LGSurfaceShadow dropShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, -1.0f) blur:0.0f];
    appearance.actionMuteIconAssetName = @"volume-up-fill-22";
    appearance.actionUnmuteIconAssetName = @"volume-mute-fill-22";
    appearance.actionShareIconAssetName = @"reply-all-fill-20";
    if (dark)
    {
        appearance.scrollButtonFillColor = [black colorWithAlphaComponent:0.6f];
        appearance.scrollButtonGlyphColor = white;
        appearance.scrollButtonGlyphLineWidth = 3.2f;
        appearance.scrollButtonInsets = UIEdgeInsetsMake(0.0f, 0.0f, 15.0f, appearance.backgroundCardHorizontalInset + 15.0f);
    }
    else
    {
        appearance.scrollButtonInsets = UIEdgeInsetsMake(0.0f, 0.0f, 6.0f, 6.0f);
    }

    LGSurfaceStyle *pinnedPanel = LGConversationTextureStyle(@"metal2.jpg", 0.0f, NO);
    pinnedPanel.shape = dark ? LGSurfaceShapeSheet : LGSurfaceShapeBand;
    pinnedPanel.cornerRadius = dark ? 13.0f : 0.0f;
    pinnedPanel.shadows = @[
        [LGSurfaceShadow dropShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f],
        [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
    ];
    appearance.pinnedPanelSurfaceStyle = pinnedPanel;
    LGSurfaceStyle *joinedPinnedPanel = [pinnedPanel copy];
    joinedPinnedPanel.shape = LGSurfaceShapeBand;
    joinedPinnedPanel.cornerRadius = 0.0f;
    appearance.joinedPinnedPanelSurfaceStyle = joinedPinnedPanel;

    LGSurfaceStyle *pinnedIndicator = [[LGSurfaceStyle alloc] init];
    pinnedIndicator.shape = LGSurfaceShapeRoundedRect;
    pinnedIndicator.cornerRadius = 1.0f;
    pinnedIndicator.layers = @[LGConversationLayer(UIEdgeInsetsZero, 0.0f, 0.0f, NO, NO, 0.0f, @[LGConversationRGB(60.0f, 125.0f, 190.0f, 1.0f), LGConversationRGB(60.0f, 125.0f, 190.0f, 1.0f), LGConversationRGB(39.0f, 83.0f, 144.0f, 1.0f)], @[@0.0f, @0.5077f, @1.0f], 180.0f, LGSurfaceBlendModeNormal, @[])];
    appearance.pinnedIndicatorSurfaceStyle = pinnedIndicator;

    appearance.pinnedBubbleSurfaceStyle = LGConversationBubbleStyle(YES, NO, NO);
    appearance.pinnedBubbleImageInsets = UIEdgeInsetsMake(2.0f, 2.0f, 3.0f, 8.0f);
    appearance.pinnedBubbleHeight = 26.0f;
    appearance.pinnedBubbleTop = 5.0f;
    appearance.pinnedPanelHeight = appearance.pinnedBubbleHeight + appearance.pinnedBubbleTop * 2.0f;
    CGFloat pinnedIndicatorHeight = appearance.pinnedPanelHeight - (dark ? 12.0f : 7.0f);
    appearance.pinnedIndicatorFrame = CGRectMake(4.0f, (appearance.pinnedPanelHeight - pinnedIndicatorHeight) / 2.0f, 4.0f, pinnedIndicatorHeight);
    appearance.pinnedTextFont = LGConversationFont(@"HelveticaNeue", 16.0f, NO);
    appearance.pinnedTextColor = black;
    appearance.pinnedTextShadowColor = [white colorWithAlphaComponent:0.8f];
    appearance.pinnedTextShadowOffset = CGSizeMake(0.0f, 0.5f);
    appearance.pinnedIconAssetName = @"pin-angle-fill";
    appearance.pinnedIconColors = @[LGConversationRGB(56.0f, 56.0f, 56.0f, 1.0f), LGConversationRGB(29.0f, 28.0f, 28.0f, 1.0f)];
    appearance.pinnedIconSize = CGSizeMake(16.0f, 16.0f);
    appearance.pinnedCloseSize = CGSizeMake(20.0f, 20.0f);
    appearance.pinnedIconTop = appearance.pinnedBubbleTop + (appearance.pinnedBubbleHeight - appearance.pinnedIconSize.height) / 2.0f;
    appearance.pinnedCloseTop = appearance.pinnedBubbleTop + (appearance.pinnedBubbleHeight - appearance.pinnedCloseSize.height) / 2.0f;
    appearance.pinnedCloseGlyphInset = 5.625f;
    appearance.pinnedCloseLineWidth = 1.5f;
    if (dark)
    {
        appearance.pinnedBubbleLeft = 13.0f;
        appearance.pinnedBubbleRightInset = 24.0f;
        appearance.pinnedTextInsets = UIEdgeInsetsMake(2.0f, 10.0f, 4.0f, 39.0f);
        appearance.pinnedIconRightInset = 30.0f;
        appearance.pinnedCloseRightInset = 1.0f;
        appearance.pinnedCloseColor = LGConversationRGB(96.0f, 96.0f, 96.0f, 0.8f);
    }
    else
    {
        appearance.pinnedBubbleLeft = 17.0f;
        appearance.pinnedBubbleRightInset = 34.0f;
        appearance.pinnedTextInsets = UIEdgeInsetsMake(2.0f, 12.0f, 4.0f, 39.0f);
        appearance.pinnedIconRightInset = 40.0f;
        appearance.pinnedCloseRightInset = 3.0f;
        appearance.pinnedCloseColor = LGConversationRGB(83.0f, 83.0f, 83.0f, 1.0f);
    }

    LGSurfaceStyle *unreadHeader = [[LGSurfaceStyle alloc] init];
    unreadHeader.shape = LGSurfaceShapeRoundedRect;
    unreadHeader.cornerRadius = 0.0f;
    unreadHeader.fillColor = LGConversationRGB(242.0f, 250.0f, 255.0f, 0.01f);
    unreadHeader.shadows = @[
        [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, -1.0f) blur:0.5f],
        [LGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
    ];
    appearance.unreadHeaderSurfaceStyle = unreadHeader;
    appearance.unreadHeaderHeight = 24.0f;
    appearance.unreadHeaderFont = LGConversationFont(@"HelveticaNeue-Medium", 14.0f, NO);
    appearance.unreadHeaderTextColor = LGConversationRGB(125.0f, 125.0f, 125.0f, 1.0f);
    appearance.unreadHeaderTextShadowColor = [black colorWithAlphaComponent:0.1f];
    appearance.unreadHeaderTextShadowOffset = CGSizeMake(0.0f, 1.0f);
    appearance.unreadHeaderTextVerticalOffset = -1.0f;

    appearance.commentsFooterHeight = 32.0f;
    appearance.commentsSeparatorColor = LGConversationRGB(143.0f, 144.0f, 146.0f, 1.0f);
    appearance.commentsAvatarSize = 20.0f;
    appearance.commentsAvatarCornerRadius = 4.0f;
    appearance.commentsAvatarLeft = 7.5f;
    appearance.commentsAvatarStep = 7.25f;
    appearance.commentsAvatarMaximumCount = 2;
    LGSurfaceStyle *commentsAvatarOverlay = [[LGSurfaceStyle alloc] init];
    commentsAvatarOverlay.shape = LGSurfaceShapeRoundedRect;
    commentsAvatarOverlay.cornerRadius = 4.0f;
    commentsAvatarOverlay.fillColor = [UIColor clearColor];
    commentsAvatarOverlay.shadows = @[
        [LGSurfaceShadow dropShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f],
        [LGSurfaceShadow insetShadowWithColor:white offset:CGSizeZero blur:0.0f spread:0.5f]
    ];
    appearance.commentsAvatarOverlaySurfaceStyle = commentsAvatarOverlay;
    appearance.commentsTitleSpacing = 8.0f;
    appearance.commentsTitleLeftWithoutAvatars = 12.0f;
    appearance.commentsTitleFont = LGConversationFont(@"HelveticaNeue-Bold", 16.0f, YES);
    appearance.commentsCountFont = LGConversationFont(@"HelveticaNeue", 16.0f, NO);
    appearance.commentsTextColor = LGConversationRGB(117.0f, 118.0f, 121.0f, 1.0f);
    UIColor *commentsChevronColor = LGConversationRGB(119.0f, 121.0f, 124.0f, 1.0f);
    appearance.commentsChevronResourceDirectory = @"ios6style";
    appearance.commentsChevronAssetName = @"drill-in";
    appearance.commentsChevronColors = @[commentsChevronColor, commentsChevronColor];
    appearance.commentsChevronLocations = @[@0.0f, @1.0f];
    appearance.commentsChevronRightInset = 4.0f;
    appearance.commentsCountSpacing = 5.5f;
    appearance.commentsTimeBottomSpacing = 5.0f;
    appearance.reactionsSpacing = 3.0f;
    appearance.reactionsTimeSpacing = 8.0f;
    appearance.reactionsTopSpacing = 4.0f;

    LGSurfaceStyle *avatarOverlay = [[LGSurfaceStyle alloc] init];
    avatarOverlay.shape = LGSurfaceShapeRoundedRect;
    avatarOverlay.cornerRadius = 10.0f;
    avatarOverlay.fillColor = [UIColor clearColor];
    UIColor *avatarShadowColor = [black colorWithAlphaComponent:0.25f];
    avatarOverlay.shadows = @[
        [LGSurfaceShadow dropShadowWithColor:avatarShadowColor offset:CGSizeMake(0.0f, 2.0f) blur:2.0f],
        [LGSurfaceShadow dropShadowWithColor:avatarShadowColor offset:CGSizeMake(0.0f, 2.0f) blur:2.0f],
        [LGSurfaceShadow dropShadowWithColor:avatarShadowColor offset:CGSizeMake(0.0f, 2.0f) blur:2.0f],
        [LGSurfaceShadow insetShadowWithColor:dark ? LGConversationRGB(177.0f, 176.0f, 176.0f, 1.0f) : LGConversationRGB(216.0f, 229.0f, 241.0f, 1.0f) offset:CGSizeZero blur:0.0f spread:1.5f],
        [LGSurfaceShadow insetShadowWithColor:avatarShadowColor offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
    ];
    appearance.avatarOverlaySurfaceStyle = avatarOverlay;
    appearance.avatarSize = 35.0f;
    appearance.avatarCornerRadius = 10.0f;
    appearance.avatarRightInset = 7.0f;
    appearance.avatarTopInset = 3.0f;
    appearance.titlePortraitOffset = -4.0f;
    appearance.subtitlePortraitOffset = 1.0f;
    appearance.titleColor = white;
    appearance.subtitleFont = LGConversationFont(@"HelveticaNeue", 10.0f, NO);
    appearance.subtitleColor = dark ? LGConversationRGB(207.0f, 207.0f, 207.0f, 1.0f) : white;

    appearance.subtitleShadowColor = [black colorWithAlphaComponent:0.3f];
    appearance.subtitleShadowOffset = CGSizeMake(0.0f, dark ? 0.5f : 1.0f);
    return appearance;
}

@end
