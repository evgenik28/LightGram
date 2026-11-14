#import "LGMusicPlayerScreenAppearance.h"
#import "LGSurfaceStyle.h"

static UIColor *LGMusicPlayerScreenRGBA(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
    return [UIColor colorWithRed:red / 255.0f green:green / 255.0f blue:blue / 255.0f alpha:alpha];
}

static UIFont *LGMusicPlayerScreenFont(NSString *name, NSString *fallbackName, CGFloat size)
{
    UIFont *font = [UIFont fontWithName:name size:size];
    if (font == nil)
        font = [UIFont fontWithName:fallbackName size:size];
    return font != nil ? font : [UIFont systemFontOfSize:size];
}

static LGSurfaceShadow *LGMusicPlayerScreenInset(UIColor *color, CGFloat x, CGFloat y, CGFloat blur)
{
    return [LGSurfaceShadow insetShadowWithColor:color offset:CGSizeMake(x, y) blur:blur];
}

static LGSurfaceShadow *LGMusicPlayerScreenDrop(UIColor *color, CGFloat x, CGFloat y, CGFloat blur)
{
    return [LGSurfaceShadow dropShadowWithColor:color offset:CGSizeMake(x, y) blur:blur];
}

static LGMusicPlayerScreenGlyphStyle *LGMusicPlayerScreenGlyph(NSArray *colors, NSArray *shadows)
{
    LGMusicPlayerScreenGlyphStyle *style = [[LGMusicPlayerScreenGlyphStyle alloc] init];
    style.colors = colors;
    style.locations = @[@0.0f, @1.0f];
    style.shadows = shadows;
    return style;
}

static LGSurfaceStyle *LGMusicPlayerScreenMetalStyle(CGFloat cornerRadius, CGRect textureRect, CGFloat contrast, UIColor *tintColor, NSArray *shadows)
{
    const CGSize textureSize = CGSizeMake(749.0f, 861.0f);
    LGSurfaceStyle *style = [[LGSurfaceStyle alloc] init];
    style.shape = LGSurfaceShapeRoundedRect;
    style.cornerRadius = cornerRadius;
    style.textureResourceDirectory = @"ios6style";
    style.textureAssetName = @"circle-metal.jpg";
    style.textureContentsRect = CGRectMake(textureRect.origin.x / textureSize.width, textureRect.origin.y / textureSize.height, textureRect.size.width / textureSize.width, textureRect.size.height / textureSize.height);
    style.textureReferenceWidth = 1.0f;
    style.textureContrast = contrast;
    style.textureTintColor = tintColor;
    style.shadows = shadows;
    return style;
}

static LGSurfaceStyle *LGMusicPlayerScreenPressedStyle(LGSurfaceStyle *style)
{
    LGSurfaceStyle *pressed = [style copy];
    pressed.overlayColor = [UIColor colorWithWhite:0.0f alpha:0.15f];
    return pressed;
}

static LGSurfaceStyle *LGMusicPlayerScreenTrackStyle(NSArray *colors, NSArray *shadows)
{
    LGSurfaceLayer *gradient = [[LGSurfaceLayer alloc] init];
    gradient.colors = colors;
    gradient.locations = @[@0.0f, @1.0f];
    gradient.cornerRadius = 4.0f;

    LGSurfaceStyle *style = [[LGSurfaceStyle alloc] init];
    style.shape = LGSurfaceShapeRoundedRect;
    style.cornerRadius = 4.0f;
    style.layers = @[gradient];
    style.shadows = shadows;
    return style;
}

@implementation LGMusicPlayerScreenGlyphStyle

- (UIEdgeInsets)symmetricOutsets
{
    CGFloat outset = 0.0f;
    for (LGSurfaceShadow *shadow in _shadows)
    {
        UIEdgeInsets shadowOutsets = [shadow outsets];
        outset = MAX(outset, MAX(MAX(shadowOutsets.top, shadowOutsets.bottom), MAX(shadowOutsets.left, shadowOutsets.right)));
    }
    return UIEdgeInsetsMake(outset, outset, outset, outset);
}

@end

@implementation LGMusicPlayerScreenAppearance

+ (LGMusicPlayerScreenAppearance *)brandedAppearance
{
    LGMusicPlayerScreenAppearance *appearance = [[LGMusicPlayerScreenAppearance alloc] init];
    UIColor *black = [UIColor blackColor];
    UIColor *white = [UIColor whiteColor];

    appearance.resourceDirectory = @"ios6style";
    appearance.statusBarBackgroundColor = black;

    LGSurfaceStyle *background = [[LGSurfaceStyle alloc] init];
    background.shape = LGSurfaceShapeBand;
    background.textureResourceDirectory = @"ios6style";
    background.textureAssetName = @"metal1.jpg";
    background.textureReferenceWidth = 1.0f;
    background.textureContrast = 0.635f;
    background.textureTintColor = LGMusicPlayerScreenRGBA(89.9f, 89.8f, 95.9f, 1.0f);
    background.shadows = @[LGMusicPlayerScreenInset([white colorWithAlphaComponent:0.7f], 0.0f, 2.0f, 0.5f)];
    appearance.backgroundSurfaceStyle = background;

    appearance.titleFont = LGMusicPlayerScreenFont(@"HelveticaNeue-Medium", @"HelveticaNeue-Bold", 20.0f);
    appearance.titleColor = LGMusicPlayerScreenRGBA(65.0f, 65.0f, 65.0f, 0.8f);
    appearance.titleTopInset = 12.0f;
    appearance.titleHeight = 24.0f;
    appearance.titleHorizontalOffset = 0.5f;

    appearance.backButtonSurfaceStyle = LGMusicPlayerScreenMetalStyle(5.0f, CGRectMake(22.0f, 92.0f, 282.0f, 148.7f), 0.775f, LGMusicPlayerScreenRGBA(62.6f, 61.6f, 62.5f, 1.0f), @[
        LGMusicPlayerScreenDrop([white colorWithAlphaComponent:0.1f], 0.0f, 1.0f, 1.0f),
        LGMusicPlayerScreenInset([white colorWithAlphaComponent:0.6f], 0.0f, -1.0f, 0.5f),
        LGMusicPlayerScreenInset([white colorWithAlphaComponent:0.5f], 0.0f, -0.5f, 0.0f),
        LGMusicPlayerScreenInset(black, 0.0f, 0.0f, 1.0f),
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.4f], 0.0f, 1.0f, 0.5f),
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.4f], 0.0f, 0.0f, 5.0f)
    ]);
    appearance.backButtonPressedSurfaceStyle = LGMusicPlayerScreenPressedStyle(appearance.backButtonSurfaceStyle);
    appearance.backButtonFont = LGMusicPlayerScreenFont(@"HelveticaNeue-Bold", @"Helvetica-Bold", 12.0f);
    appearance.backButtonTitleColor = LGMusicPlayerScreenRGBA(77.0f, 77.0f, 77.0f, 1.0f);
    appearance.backButtonOrigin = CGPointMake(10.5f, 10.0f);
    appearance.backButtonHeight = 29.0f;
    appearance.backButtonMinimumWidth = 55.0f;
    appearance.backButtonHorizontalPadding = 10.0f;

    LGSurfaceStyle *display = [[LGSurfaceStyle alloc] init];
    display.shape = LGSurfaceShapeRoundedRect;
    display.cornerRadius = 50.0f;
    display.fillColor = LGMusicPlayerScreenRGBA(215.0f, 219.0f, 192.0f, 1.0f);
    display.shadows = @[
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.25f], 0.0f, 4.0f, 4.0f),
        LGMusicPlayerScreenInset([white colorWithAlphaComponent:0.7f], 0.0f, -2.0f, 0.5f),
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.3f], 0.0f, 2.0f, 0.5f)
    ];
    appearance.displaySurfaceStyle = display;
    appearance.displayTopInset = 49.0f;
    appearance.displayLeftInset = 12.0f;
    appearance.displayRightInset = 8.0f;
    appearance.displayHeight = 74.0f;
    appearance.displayTextHorizontalInset = 30.0f;
    appearance.displayTitleFont = LGMusicPlayerScreenFont(@"HelveticaNeue-Medium", @"HelveticaNeue-Bold", 16.0f);
    appearance.displayTitleColor = LGMusicPlayerScreenRGBA(55.0f, 55.0f, 55.0f, 1.0f);
    appearance.displayTitleTopInset = 8.0f;
    appearance.displayTitleHeight = 20.0f;
    appearance.displayTitleHorizontalOffset = -1.0f;
    appearance.displaySubtitleFont = LGMusicPlayerScreenFont(@"HelveticaNeue-Medium", @"HelveticaNeue-Bold", 12.0f);
    appearance.displaySubtitleColor = LGMusicPlayerScreenRGBA(91.0f, 91.0f, 91.0f, 1.0f);
    appearance.displaySubtitleTopInset = 29.0f;
    appearance.displaySubtitleHeight = 15.0f;
    appearance.displaySubtitleHorizontalOffset = -1.0f;
    appearance.progressLeftInset = 21.0f;
    appearance.progressRightInset = 20.0f;
    appearance.progressTopInset = 52.0f;
    appearance.progressHeight = 11.0f;
    appearance.progressBorderWidth = 1.0f;
    appearance.progressBorderColor = black;
    appearance.progressFillColor = LGMusicPlayerScreenRGBA(107.0f, 107.0f, 107.0f, 0.4f);
    appearance.progressKnobColor = LGMusicPlayerScreenRGBA(6.0f, 6.0f, 6.0f, 1.0f);
    appearance.progressKnobSize = 6.36f;
    appearance.progressTouchOutset = 14.0f;

    LGSurfaceStyle *playlist = [[LGSurfaceStyle alloc] init];
    playlist.shape = LGSurfaceShapeRoundedRect;
    playlist.cornerRadius = 10.0f;
    playlist.fillColor = white;
    appearance.playlistSurfaceStyle = playlist;

    LGSurfaceStyle *playlistOverlay = [[LGSurfaceStyle alloc] init];
    playlistOverlay.shape = LGSurfaceShapeRoundedRect;
    playlistOverlay.cornerRadius = 10.0f;
    playlistOverlay.fillColor = [UIColor clearColor];
    playlistOverlay.shadows = @[
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.25f], 0.0f, 2.0f, 4.0f),
        LGMusicPlayerScreenInset([white colorWithAlphaComponent:0.3f], 0.0f, -2.0f, 1.0f),
        LGMusicPlayerScreenInset(white, 0.0f, -1.0f, 0.5f),
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.3f], 0.0f, 4.0f, 2.0f),
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.3f], 0.0f, 2.0f, 1.0f)
    ];
    appearance.playlistOverlaySurfaceStyle = playlistOverlay;
    appearance.playlistTopInset = 147.0f;
    appearance.playlistHorizontalInset = 8.0f;
    appearance.playlistBottomSpacing = 21.0f;
    appearance.playlistCornerRadius = 10.0f;
    appearance.rowHeight = 32.0f;

    LGSurfaceStyle *row = [[LGSurfaceStyle alloc] init];
    row.shape = LGSurfaceShapeRoundedRect;
    row.fillColor = [UIColor clearColor];
    row.shadows = @[LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.3f], 0.0f, -1.0f, 1.0f)];
    appearance.rowSurfaceStyle = row;
    appearance.rowHighlightColor = [black colorWithAlphaComponent:0.1f];
    appearance.rowIconName = @"ipod-note";
    UIColor *noteColor = LGMusicPlayerScreenRGBA(96.0f, 96.0f, 96.0f, 1.0f);
    appearance.rowIconStyle = LGMusicPlayerScreenGlyph(@[noteColor, noteColor], @[LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.3f], 0.0f, 1.0f, 0.5f)]);
    appearance.rowIconOrigin = CGPointMake(11.0f, 8.0f);
    appearance.rowTitleFont = LGMusicPlayerScreenFont(@"HelveticaNeue-Medium", @"HelveticaNeue-Bold", 14.0f);
    appearance.rowTitleColor = LGMusicPlayerScreenRGBA(55.0f, 55.0f, 55.0f, 1.0f);
    appearance.rowTitleLeftInset = 36.0f;
    appearance.rowTitleRightInset = 55.0f;
    appearance.rowTitleTopInset = 7.0f;
    appearance.rowTitleHeight = 17.0f;
    appearance.rowDurationFont = LGMusicPlayerScreenFont(@"HelveticaNeue", @"Helvetica", 12.0f);
    appearance.rowDurationColor = LGMusicPlayerScreenRGBA(89.0f, 89.0f, 89.0f, 1.0f);
    appearance.rowDurationCenterRightInset = 34.0f;
    appearance.rowDurationWidth = 34.0f;
    appearance.rowDurationTopInset = 9.0f;
    appearance.rowDurationHeight = 14.0f;

    NSArray *buttonShadows = @[
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.6f], 0.0f, 1.5f, 0.5f),
        LGMusicPlayerScreenInset([white colorWithAlphaComponent:0.8f], 0.0f, -1.5f, 0.5f)
    ];
    appearance.largeButtonDiameter = 81.0f;
    appearance.smallButtonDiameter = 67.0f;
    CGRect buttonTextureRect = CGRectMake(26.5f, 21.5f, 288.0f, 288.0f);
    UIColor *largeButtonTint = LGMusicPlayerScreenRGBA(122.3f, 121.8f, 123.4f, 1.0f);
    UIColor *smallButtonTint = LGMusicPlayerScreenRGBA(107.6f, 106.9f, 107.8f, 1.0f);
    appearance.largeButtonSurfaceStyle = LGMusicPlayerScreenMetalStyle(appearance.largeButtonDiameter / 2.0f, buttonTextureRect, 0.506f, largeButtonTint, buttonShadows);
    appearance.largeButtonPressedSurfaceStyle = LGMusicPlayerScreenPressedStyle(appearance.largeButtonSurfaceStyle);
    appearance.smallButtonSurfaceStyle = LGMusicPlayerScreenMetalStyle(appearance.smallButtonDiameter / 2.0f, buttonTextureRect, 0.605f, smallButtonTint, buttonShadows);
    appearance.smallButtonPressedSurfaceStyle = LGMusicPlayerScreenPressedStyle(appearance.smallButtonSurfaceStyle);
    appearance.transportBottomInset = 134.0f;
    appearance.transportCenterOffset = -0.5f;
    appearance.smallButtonTopOffset = 6.0f;
    appearance.smallButtonCenterSpacing = 86.0f;
    appearance.rewindIconName = @"ipod-rewind";
    appearance.forwardIconName = @"ipod-forward";
    appearance.playIconName = @"ipod-play";
    appearance.pauseIconName = @"ipod-pause";
    NSArray *glyphColors = @[LGMusicPlayerScreenRGBA(134.0f, 134.0f, 134.0f, 1.0f), LGMusicPlayerScreenRGBA(42.0f, 41.0f, 41.0f, 1.0f)];
    appearance.rewindGlyphStyle = LGMusicPlayerScreenGlyph(glyphColors, @[
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.3f], 0.0f, 1.34415f, 0.672075f),
        LGMusicPlayerScreenDrop([white colorWithAlphaComponent:0.5f], 0.0f, 1.34415f, 0.672075f)
    ]);
    appearance.forwardGlyphStyle = LGMusicPlayerScreenGlyph(glyphColors, @[
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.3f], 0.0f, 1.0f, 0.5f),
        LGMusicPlayerScreenDrop([white colorWithAlphaComponent:0.5f], 0.0f, 1.0f, 0.5f)
    ]);
    appearance.playPauseGlyphStyle = LGMusicPlayerScreenGlyph(glyphColors, @[
        LGMusicPlayerScreenInset([white colorWithAlphaComponent:0.8f], 0.0f, -1.34415f, 0.672075f),
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.3f], 0.0f, 1.34415f, 0.672075f)
    ]);
    appearance.rewindGlyphOffset = CGPointMake(-1.0f, 0.5f);
    appearance.forwardGlyphOffset = CGPointMake(1.0f, 0.5f);
    appearance.pauseGlyphOffset = CGPointMake(0.0f, 1.0f);
    appearance.playGlyphOffset = CGPointMake(1.5f, 1.0f);
    appearance.disabledControlAlpha = 0.6f;

    appearance.repeatIconName = @"ipod-repeat";
    appearance.repeatOneIconName = @"ipod-repeat-one";
    appearance.shuffleIconName = @"ipod-shuffle";
    appearance.reverseIconName = @"ipod-reverse";
    NSArray *modeGlyphShadows = @[
        LGMusicPlayerScreenDrop([white colorWithAlphaComponent:0.8f], 0.0f, 1.0f, 0.5f),
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.6f], 0.0f, 1.0f, 0.5f)
    ];
    NSArray *modeGlyphColors = @[LGMusicPlayerScreenRGBA(154.0f, 154.0f, 154.0f, 1.0f), LGMusicPlayerScreenRGBA(81.0f, 81.0f, 81.0f, 1.0f)];
    LGMusicPlayerScreenGlyphStyle *repeatGlyphStyle = LGMusicPlayerScreenGlyph(modeGlyphColors, modeGlyphShadows);
    repeatGlyphStyle.locations = @[@-0.2f, @0.9f];
    appearance.repeatGlyphStyle = repeatGlyphStyle;
    LGMusicPlayerScreenGlyphStyle *orderGlyphStyle = LGMusicPlayerScreenGlyph(modeGlyphColors, modeGlyphShadows);
    orderGlyphStyle.locations = @[@-0.3f, @0.8667f];
    appearance.orderGlyphStyle = orderGlyphStyle;
    LGMusicPlayerScreenGlyphStyle *modeSelected = [[LGMusicPlayerScreenGlyphStyle alloc] init];
    modeSelected.colors = @[white, LGMusicPlayerScreenRGBA(39.0f, 138.0f, 242.0f, 1.0f), LGMusicPlayerScreenRGBA(62.0f, 201.0f, 251.0f, 1.0f)];
    modeSelected.locations = @[@0.0f, @0.5f, @1.0f];
    modeSelected.shadows = @[
        LGMusicPlayerScreenInset([white colorWithAlphaComponent:0.6f], 0.0f, 1.0f, 0.5f),
        LGMusicPlayerScreenDrop(LGMusicPlayerScreenRGBA(4.0f, 130.0f, 255.0f, 0.8f), 0.0f, 0.0f, 3.0f),
        LGMusicPlayerScreenDrop([black colorWithAlphaComponent:0.7f], 0.0f, 1.0f, 0.5f)
    ];
    appearance.modeSelectedGlyphStyle = modeSelected;
    appearance.modeGlyphOpticalSize = 11.87f;
    appearance.modeGlyphOffset = CGPointMake(0.5f, 0.5f);
    appearance.modeButtonDiameter = 21.0f;
    appearance.modeButtonSurfaceStyle = LGMusicPlayerScreenMetalStyle(appearance.modeButtonDiameter / 2.0f, buttonTextureRect, 0.605f, smallButtonTint, @[
        LGMusicPlayerScreenInset([white colorWithAlphaComponent:0.8f], 0.0f, -1.5f, 0.5f),
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.6f], 0.0f, 1.5f, 0.5f)
    ]);
    appearance.modeButtonPressedSurfaceStyle = LGMusicPlayerScreenPressedStyle(appearance.modeButtonSurfaceStyle);
    appearance.modeButtonSideInset = 12.0f;
    appearance.modeButtonBottomInset = 103.0f;
    appearance.modeButtonTouchSize = 44.0f;

    appearance.volumeMinimumTrackSurfaceStyle = LGMusicPlayerScreenTrackStyle(@[LGMusicPlayerScreenRGBA(168.0f, 194.0f, 231.0f, 1.0f), LGMusicPlayerScreenRGBA(28.0f, 78.0f, 170.0f, 1.0f)], @[
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.2f], 0.0f, 1.0f, 1.0f),
        LGMusicPlayerScreenInset([white colorWithAlphaComponent:0.1f], 0.0f, -1.0f, 1.0f)
    ]);
    appearance.volumeMaximumTrackSurfaceStyle = LGMusicPlayerScreenTrackStyle(@[LGMusicPlayerScreenRGBA(184.0f, 184.0f, 184.0f, 1.0f), white], @[
        LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.3f], 0.0f, 1.0f, 1.0f),
        LGMusicPlayerScreenInset([white colorWithAlphaComponent:0.2f], 0.0f, -1.0f, 1.0f)
    ]);

    appearance.volumeThumbDiameter = 22.0f;
    LGSurfaceLayer *knobBrushing = [[LGSurfaceLayer alloc] init];
    knobBrushing.cornerRadius = appearance.volumeThumbDiameter / 2.0f;
    knobBrushing.conicGradient = YES;
    knobBrushing.gradientAngle = 180.0f;
    UIColor *knobDark = [black colorWithAlphaComponent:0.4f];
    UIColor *knobLight = [black colorWithAlphaComponent:0.2f];
    knobBrushing.colors = @[knobDark, knobLight, knobDark, knobLight, knobDark, knobLight, knobDark, knobLight, knobDark];
    knobBrushing.locations = @[@0.0f, @(45.0f / 360.0f), @(90.0f / 360.0f), @(136.8f / 360.0f), @(180.0f / 360.0f), @(226.8f / 360.0f), @(270.0f / 360.0f), @(316.8f / 360.0f), @1.0f];
    LGSurfaceStyle *knob = [[LGSurfaceStyle alloc] init];
    knob.shape = LGSurfaceShapeRoundedRect;
    knob.cornerRadius = appearance.volumeThumbDiameter / 2.0f;
    knob.fillColor = white;
    knob.layers = @[knobBrushing];
    knob.shadows = @[
        LGMusicPlayerScreenDrop([black colorWithAlphaComponent:0.6f], 0.0f, 2.0f, 2.0f),
        [LGSurfaceShadow insetShadowWithColor:[white colorWithAlphaComponent:0.6f] offset:CGSizeZero blur:0.0f spread:0.5f]
    ];
    appearance.volumeThumbSurfaceStyle = knob;
    appearance.volumeTrackHeight = 10.0f;
    appearance.volumeTrackVerticalOffset = 1.0f;
    appearance.volumeIconVerticalOffset = -1.0f;
    appearance.volumeTrackLeftInset = 49.0f;
    appearance.volumeTrackRightInset = 54.0f;
    appearance.volumeCenterBottomInset = 25.0f;
    appearance.volumeLowIconName = @"ipod-volume-off";
    appearance.volumeHighIconName = @"ipod-volume-up";
    UIColor *volumeColor = LGMusicPlayerScreenRGBA(69.0f, 69.0f, 69.0f, 1.0f);
    appearance.volumeGlyphStyle = LGMusicPlayerScreenGlyph(@[volumeColor, volumeColor], @[LGMusicPlayerScreenInset([black colorWithAlphaComponent:0.3f], 0.0f, 1.0f, 0.5f)]);
    appearance.volumeLowIconLeftInset = 34.0f;
    appearance.volumeHighIconRightInset = 35.0f;

    return appearance;
}

@end
