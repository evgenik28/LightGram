#import "LGProfileHeader.h"
#import "../Core/LGTheme.h"
#import "../Core/LGAssets.h"
#import "../Core/LGProfileAppearance.h"
#import "../../LightGramPlatform/LGPlatformVersion.h"
#import "../../LightGramPlatform/LGPlatformGraphics.h"
#import "../Core/LGSurfaceStyle.h"
#import "../Core/LGSurfaceRenderer.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static char LGProfileHeaderMusicCardStyleKey;
static char LGProfileHeaderMusicPlayImageKey;

static UIEdgeInsets LGProfileHeaderStyleOutsets(LGSurfaceStyle *style)
{
    if (style == nil)
        return UIEdgeInsetsZero;
    UIEdgeInsets outsets = [style dropShadowOutsets];
    return UIEdgeInsetsMake(ceilf(outsets.top), ceilf(outsets.left), ceilf(outsets.bottom), ceilf(outsets.right));
}

static UIImage *LGProfileHeaderSurfaceImage(LGTheme *theme, LGSurfaceStyle *style, CGSize size, UIEdgeInsets *outsets)
{
    UIEdgeInsets styleOutsets = LGProfileHeaderStyleOutsets(style);
    if (outsets != NULL)
        *outsets = styleOutsets;
    if (style == nil || size.width < 1.0f || size.height < 1.0f)
        return nil;
    CGSize imageSize = CGSizeMake(styleOutsets.left + size.width + styleOutsets.right, styleOutsets.top + size.height + styleOutsets.bottom);
    return [theme.surfaceRenderer imageWithStyle:style size:imageSize bodyFrame:CGRectMake(styleOutsets.left, styleOutsets.top, size.width, size.height)];
}

@implementation LGProfileHeader

+ (LGSurfaceStyle *)legacyMusicCardStyleWithTheme:(LGTheme *)theme
{
    LGSurfaceStyle *cachedStyle = objc_getAssociatedObject(theme, &LGProfileHeaderMusicCardStyleKey);
    if (cachedStyle != nil)
        return cachedStyle;
    LGProfileAppearance *appearance = theme.profileAppearance;
    LGSurfaceStyle *style = [appearance.cardSurfaceStyle copy];
    if (appearance.cardMusicLayer != nil)
        style.layers = [(style.layers ?: @[]) arrayByAddingObject:appearance.cardMusicLayer];
    objc_setAssociatedObject(theme, &LGProfileHeaderMusicCardStyleKey, style, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return style;
}

+ (UIImage *)legacyCardImageWithTheme:(LGTheme *)theme size:(CGSize)size hasMusic:(BOOL)hasMusic outsets:(UIEdgeInsets *)outsets
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    LGSurfaceStyle *style = hasMusic ? [self legacyMusicCardStyleWithTheme:theme] : theme.profileAppearance.cardSurfaceStyle;
    return LGProfileHeaderSurfaceImage(theme, style, size, outsets);
}

+ (UIImage *)legacyAvatarOverlayImageWithTheme:(LGTheme *)theme size:(CGSize)size outsets:(UIEdgeInsets *)outsets
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    return LGProfileHeaderSurfaceImage(theme, theme.profileAppearance.avatarOverlaySurfaceStyle, size, outsets);
}

+ (UIImage *)legacyStatusBackgroundImageWithTheme:(LGTheme *)theme size:(CGSize)size outsets:(UIEdgeInsets *)outsets
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    return LGProfileHeaderSurfaceImage(theme, theme.profileAppearance.statusSurfaceStyle, size, outsets);
}

+ (UIImage *)legacyMusicPlayImageWithTheme:(LGTheme *)theme outsets:(UIEdgeInsets *)outsets
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    LGProfileAppearance *appearance = theme.profileAppearance;
    UIEdgeInsets circleOutsets = UIEdgeInsetsZero;
    CGSize circleSize = CGSizeMake(appearance.musicArrowSize, appearance.musicArrowSize);
    UIImage *circleImage = LGProfileHeaderSurfaceImage(theme, appearance.musicPlaySurfaceStyle, circleSize, &circleOutsets);
    if (outsets != NULL)
        *outsets = circleOutsets;

    UIImage *cachedImage = objc_getAssociatedObject(theme, &LGProfileHeaderMusicPlayImageKey);
    if (cachedImage != nil)
        return cachedImage;
    if (circleImage == nil)
        return nil;

    UIImage *glyphTemplate = [theme.assets imageNamed:appearance.musicPlayGlyphAssetName inDirectory:appearance.musicPlayGlyphResourceDirectory];
    UIEdgeInsets glyphOutsets = [appearance.musicPlayGlyphShadow outsets];
    glyphOutsets = UIEdgeInsetsMake(ceilf(glyphOutsets.top), ceilf(glyphOutsets.left), ceilf(glyphOutsets.bottom), ceilf(glyphOutsets.right));
    UIImage *glyphImage = glyphTemplate != nil ? [theme.surfaceRenderer iconImageWithTemplate:glyphTemplate gradientColors:appearance.musicPlayGlyphColors locations:appearance.musicPlayGlyphLocations shadow:appearance.musicPlayGlyphShadow outsets:glyphOutsets] : nil;

    UIGraphicsBeginImageContextWithOptions(circleImage.size, false, circleImage.scale);
    [circleImage drawAtPoint:CGPointZero];
    [glyphImage drawAtPoint:CGPointMake(circleOutsets.left + appearance.musicPlayGlyphOrigin.x - glyphOutsets.left, circleOutsets.top + appearance.musicPlayGlyphOrigin.y - glyphOutsets.top)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (image != nil)
        objc_setAssociatedObject(theme, &LGProfileHeaderMusicPlayImageKey, image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return image;
}

+ (UIFont *)legacyNameFontWithTheme:(LGTheme *)theme size:(CGFloat)size
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    NSString *fontName = theme.profileAppearance.nameFontName;
    UIFont *font = fontName.length != 0 ? [UIFont fontWithName:fontName size:size] : nil;
    return font != nil ? font : [UIFont boldSystemFontOfSize:size];
}

+ (void)applyLegacyAvatarStyleWithTheme:(LGTheme *)theme view:(UIView *)view
{
    if (view == nil)
        return;
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    LGProfileAppearance *appearance = theme.profileAppearance;
    view.clipsToBounds = true;
    view.layer.cornerRadius = appearance.avatarCornerRadius;
    view.layer.borderWidth = 0.0f;
}

+ (void)applyLegacyReflectionStyleWithTheme:(LGTheme *)theme imageView:(UIImageView *)imageView
{
    if (imageView == nil)
        return;
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    LGProfileAppearance *appearance = theme.profileAppearance;
    imageView.alpha = appearance.reflectionAlpha;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = true;
    imageView.layer.cornerRadius = appearance.avatarCornerRadius;
    CAGradientLayer *mask = [imageView.layer.mask isKindOfClass:[CAGradientLayer class]] ? (CAGradientLayer *)imageView.layer.mask : [CAGradientLayer layer];
    mask.colors = @[(id)[UIColor colorWithWhite:1.0f alpha:0.0f].CGColor, (id)[UIColor colorWithWhite:1.0f alpha:0.0f].CGColor, (id)[UIColor colorWithWhite:1.0f alpha:appearance.reflectionMaskAlpha].CGColor];
    mask.locations = @[@0.0f, @(1.0f - appearance.reflectionMaskLength), @1.0f];
    imageView.layer.mask = mask;
    LGPlatformSetLayerRasterization(imageView.layer, YES, LGPlatformScreenScale());
}

@end
