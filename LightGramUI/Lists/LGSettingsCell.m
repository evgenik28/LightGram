#import "LGSettingsCell.h"
#import "../Core/LGTheme.h"
#import "../Core/LGPalette.h"
#import "../Core/LGTypography.h"
#import "../Core/LGMetrics.h"
#import "../Core/LGGeometry.h"
#import "../Core/LGAssets.h"
#import "../Core/LGSettingsAppearance.h"
#import "../Core/LGSurfaceStyle.h"
#import "../Core/LGSurfaceRenderer.h"
#import "../../LightGramPlatform/LGPlatformGraphics.h"
#import "../../LightGramPlatform/LGPlatformVersion.h"
#import <objc/runtime.h>

static char LGSettingsCellSelectedGroupedStylesKey;

void LGSettingsCellGetLegacyLayout(LGSettingsAppearance *appearance, CGRect bounds, UIEdgeInsets safeAreaInsets, CGSize accessorySize, LGSettingsCellAccessoryKind accessoryKind, CGSize trailingSize, CGFloat trailingVerticalOffset, CGFloat titleTrailingSpacing, LGSettingsCellLegacyLayout *layout)
{
    if (layout == NULL || appearance == nil)
        return;

    CGFloat accessoryRight = accessoryKind == LGSettingsCellAccessoryControl ? appearance.controlRight : appearance.disclosureRight;
    CGFloat accessoryVerticalOffset = accessoryKind == LGSettingsCellAccessoryDisclosure ? appearance.disclosureVerticalOffset : 0.0f;
    CGFloat contentOffset = accessoryKind == LGSettingsCellAccessoryControl ? appearance.controlRowContentOffset : 0.0f;
    CGFloat rightEdge = bounds.size.width - safeAreaInsets.right;

    layout->iconFrame = CGRectMake(appearance.iconX + safeAreaInsets.left, LGPixelFloor((bounds.size.height - appearance.iconSize) * 0.5f + contentOffset) + appearance.verticalOffset, appearance.iconSize, appearance.iconSize);

    if (accessoryKind == LGSettingsCellAccessoryNone || accessorySize.width <= 0.0f || accessorySize.height <= 0.0f)
    {
        layout->accessoryFrame = CGRectZero;
    }
    else
    {
        layout->accessoryFrame = CGRectMake(rightEdge - accessoryRight - accessorySize.width, LGPixelFloor((bounds.size.height - accessorySize.height) * 0.5f + contentOffset) + accessoryVerticalOffset, accessorySize.width, accessorySize.height);
        rightEdge = CGRectGetMinX(layout->accessoryFrame) - appearance.accessorySpacing;
    }

    if (trailingSize.width > 0.0f && trailingSize.height > 0.0f)
    {
        layout->trailingFrame = CGRectMake(rightEdge - trailingSize.width, LGPixelFloor((bounds.size.height - trailingSize.height) * 0.5f + contentOffset) + trailingVerticalOffset, trailingSize.width, trailingSize.height);
        rightEdge = CGRectGetMinX(layout->trailingFrame) - appearance.accessorySpacing;
    }
    else
    {
        layout->trailingFrame = CGRectZero;
    }

    CGFloat titleX = appearance.titleX + safeAreaInsets.left;
    CGFloat titleY = LGPixelFloor((bounds.size.height - appearance.rowHeight) * 0.5f + appearance.titleY + contentOffset);
    if (accessoryKind != LGSettingsCellAccessoryNone || trailingSize.width > 0.0f)
        rightEdge -= MAX(0.0f, titleTrailingSpacing - appearance.accessorySpacing);
    layout->titleFrame = CGRectMake(titleX, titleY, MAX(0.0f, rightEdge - titleX), appearance.titleHeight);
}

void LGSettingsCellGetLegacyBrandedLayout(LGTheme *theme, CGRect bounds, UIEdgeInsets safeAreaInsets, CGSize accessorySize, LGSettingsCellAccessoryKind accessoryKind, CGSize trailingSize, CGFloat trailingVerticalOffset, CGFloat titleTrailingSpacing, LGSettingsCellLegacyLayout *layout)
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    LGSettingsCellGetLegacyLayout(theme.settingsAppearance, bounds, safeAreaInsets, accessorySize, accessoryKind, trailingSize, trailingVerticalOffset, titleTrailingSpacing, layout);
}

@implementation LGSettingsCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.showsIcon = YES;
        self.showsAccessory = YES;
        self.iconView.preferredSize = CGSizeMake(self.theme.settingsAppearance.iconSize, self.theme.settingsAppearance.iconSize);
        self.accessoryView.preferredSize = CGSizeMake(8.0f, 14.0f);
    }
    return self;
}

- (void)applyTheme
{
    [super applyTheme];
    LGSettingsAppearance *appearance = self.theme.settingsAppearance;
    self.titleLabel.font = appearance.titleFont;
    self.titleLabel.textColor = appearance.titleColor;
    self.titleLabel.shadowColor = appearance.shadowColor;
    self.titleLabel.shadowOffset = appearance.titleShadowOffset;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    LGSettingsCellLegacyLayout layout;
    LGSettingsCellGetLegacyBrandedLayout(self.theme, self.bounds, self.contentInsets, self.accessoryView.frame.size, LGSettingsCellAccessoryDisclosure, CGSizeZero, 0.0f, self.theme.settingsAppearance.titleTrailingSpacing, &layout);
    self.iconView.frame = layout.iconFrame;
    self.titleLabel.frame = layout.titleFrame;
    self.accessoryView.frame = layout.accessoryFrame;
}

+ (UIImage *)legacyBrandedIconNamed:(NSString *)name theme:(LGTheme *)theme
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    return [self legacyBrandedIconNamed:name appearance:theme.settingsAppearance theme:theme];
}

+ (UIImage *)legacyBrandedIconNamed:(NSString *)name appearance:(LGSettingsAppearance *)appearance theme:(LGTheme *)theme
{
    if ([name length] == 0)
        return nil;
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    if (appearance == nil)
        appearance = theme.settingsAppearance;
    UIImage *image = [theme.assets imageNamed:name inDirectory:appearance.iconResourceDirectory];
    if (image == nil || appearance.iconColors.count == 0)
        return image;
    return [theme.surfaceRenderer iconImageWithTemplate:image gradientColors:appearance.iconColors locations:appearance.iconLocations shadow:nil outsets:UIEdgeInsetsZero];
}

+ (UIImage *)legacyBrandedDisclosureImageWithTheme:(LGTheme *)theme
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    LGSettingsAppearance *appearance = theme.settingsAppearance;
    UIImage *image = [theme.assets imageNamed:appearance.disclosureAssetName inDirectory:appearance.disclosureResourceDirectory];
    if (image == nil || appearance.disclosureColors.count == 0)
        return image;
    return [theme.surfaceRenderer iconImageWithTemplate:image gradientColors:appearance.disclosureColors locations:appearance.disclosureLocations shadow:nil outsets:UIEdgeInsetsZero];
}

+ (LGSurfaceStyle *)legacyGroupedSurfaceStyleForPosition:(LGGroupedCellPosition)position appearance:(LGSettingsAppearance *)appearance
{
    switch (position)
    {
        case LGGroupedCellPositionSingle:
            return appearance.groupedSingleSurfaceStyle;
        case LGGroupedCellPositionTop:
            return appearance.groupedTopSurfaceStyle;
        case LGGroupedCellPositionBottom:
            return appearance.groupedBottomSurfaceStyle;
        case LGGroupedCellPositionMiddle:
        default:
            return appearance.groupedMiddleSurfaceStyle;
    }
}

+ (LGSurfaceStyle *)legacySelectedGroupedSurfaceStyleForPosition:(LGGroupedCellPosition)position appearance:(LGSettingsAppearance *)appearance
{
    LGSurfaceStyle *style = [self legacyGroupedSurfaceStyleForPosition:position appearance:appearance];
    UIColor *overlayColor = appearance.groupedSelectedOverlayColor;
    if (style == nil || overlayColor == nil)
        return style;

    NSMutableDictionary *selectedStyles = objc_getAssociatedObject(appearance, &LGSettingsCellSelectedGroupedStylesKey);
    if (selectedStyles == nil)
    {
        selectedStyles = [[NSMutableDictionary alloc] init];
        objc_setAssociatedObject(appearance, &LGSettingsCellSelectedGroupedStylesKey, selectedStyles, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    LGSurfaceStyle *selectedStyle = selectedStyles[@(position)];
    if (selectedStyle == nil)
    {
        selectedStyle = [style copy];
        selectedStyle.overlayColor = overlayColor;
        selectedStyles[@(position)] = selectedStyle;
    }
    return selectedStyle;
}

+ (BOOL)legacyGroupedBackgroundUsesSurfaceWithTheme:(LGTheme *)theme
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    return theme.settingsAppearance.groupedMiddleSurfaceStyle != nil;
}

+ (UIImage *)legacyGroupedSurfaceImageForPosition:(LGGroupedCellPosition)position selected:(BOOL)selected size:(CGSize)size theme:(LGTheme *)theme outsets:(UIEdgeInsets *)outsets
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    return [self legacyGroupedSurfaceImageForPosition:position selected:selected size:size appearance:theme.settingsAppearance theme:theme outsets:outsets];
}

+ (UIImage *)legacyGroupedSurfaceImageForPosition:(LGGroupedCellPosition)position selected:(BOOL)selected size:(CGSize)size appearance:(LGSettingsAppearance *)appearance theme:(LGTheme *)theme outsets:(UIEdgeInsets *)outsets
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    if (appearance == nil)
        appearance = theme.settingsAppearance;
    LGSurfaceStyle *style = selected ? [self legacySelectedGroupedSurfaceStyleForPosition:position appearance:appearance] : [self legacyGroupedSurfaceStyleForPosition:position appearance:appearance];
    if (style == nil)
    {
        if (outsets != NULL)
            *outsets = UIEdgeInsetsZero;
        return nil;
    }
    UIEdgeInsets styleOutsets = [style dropShadowOutsets];
    styleOutsets = UIEdgeInsetsMake(ceilf(styleOutsets.top), ceilf(styleOutsets.left), ceilf(styleOutsets.bottom), ceilf(styleOutsets.right));
    if (position == LGGroupedCellPositionTop || position == LGGroupedCellPositionMiddle)
        styleOutsets.bottom = 0.0f;
    if (outsets != NULL)
        *outsets = styleOutsets;
    if (size.width < 1.0f || size.height < 1.0f)
        return nil;
    CGSize imageSize = CGSizeMake(styleOutsets.left + size.width + styleOutsets.right, styleOutsets.top + size.height + styleOutsets.bottom);
    return [theme.surfaceRenderer imageWithStyle:style size:imageSize bodyFrame:CGRectMake(styleOutsets.left, styleOutsets.top, size.width, size.height)];
}

+ (UIColor *)legacyScreenBackgroundColorWithTheme:(LGTheme *)theme
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    LGSurfaceStyle *style = theme.settingsAppearance.screenBackgroundSurfaceStyle;
    if (style == nil)
        return nil;
    CGFloat scale = LGPlatformScreenScale();
    CGFloat tileSize = ceilf(style.textureReferenceWidth * scale) / scale;
    UIImage *tile = [theme.surfaceRenderer imageWithStyle:style size:CGSizeMake(tileSize, tileSize) bodyFrame:CGRectMake(0.0f, 0.0f, tileSize, tileSize)];
    return tile != nil ? [UIColor colorWithPatternImage:tile] : nil;
}

+ (UIImage *)legacyGroupedBackgroundImageForPosition:(LGGroupedCellPosition)position selected:(BOOL)selected theme:(LGTheme *)theme
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];

    LGSettingsAppearance *appearance = theme.settingsAppearance;
    NSString *name = nil;
    switch (position)
    {
        case LGGroupedCellPositionSingle:
            name = appearance.groupedSingleAssetName;
            break;
        case LGGroupedCellPositionTop:
            name = appearance.groupedTopAssetName;
            break;
        case LGGroupedCellPositionBottom:
            name = appearance.groupedBottomAssetName;
            break;
        case LGGroupedCellPositionMiddle:
        default:
            name = appearance.groupedMiddleAssetName;
            break;
    }

    if (selected)
        name = [name stringByAppendingString:appearance.groupedSelectedSuffix];

    UIImage *image = [theme.assets imageNamed:name inDirectory:appearance.groupedResourceDirectory];
    if (image == nil)
        return nil;
    return [image stretchableImageWithLeftCapWidth:(int)floorf(image.size.width * 0.5f) topCapHeight:(int)floorf(image.size.height * 0.5f)];
}

+ (UIColor *)legacyCollectionBackgroundColorWithTheme:(LGTheme *)theme
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    return theme.settingsAppearance.collectionBackgroundColor;
}

+ (void)applyLegacyBrandedTitleStyleWithTheme:(LGTheme *)theme titleLabel:(UILabel *)titleLabel
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    [self applyLegacyBrandedTitleStyleWithAppearance:theme.settingsAppearance titleLabel:titleLabel];
}

+ (void)applyLegacyBrandedTitleStyleWithAppearance:(LGSettingsAppearance *)appearance titleLabel:(UILabel *)titleLabel
{
    if (titleLabel == nil || appearance == nil)
        return;
    titleLabel.font = appearance.titleFont;
    titleLabel.textColor = appearance.titleColor;
    titleLabel.shadowColor = appearance.shadowColor;
    titleLabel.shadowOffset = appearance.titleShadowOffset;
}

+ (BOOL)applyLegacyBrandedHeaderStyleWithTheme:(LGTheme *)theme headerLabel:(UILabel *)headerLabel
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    LGSettingsAppearance *appearance = theme.settingsAppearance;
    if (headerLabel == nil || appearance.headerFont == nil)
        return NO;
    headerLabel.font = appearance.headerFont;
    headerLabel.textColor = appearance.headerColor;
    headerLabel.shadowColor = appearance.headerShadowColor;
    headerLabel.shadowOffset = appearance.headerShadowOffset;
    return YES;
}

+ (void)applyLegacyBrandedVariantStyleWithTheme:(LGTheme *)theme variantLabel:(UILabel *)variantLabel
{
    if (variantLabel == nil)
        return;
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    LGSettingsAppearance *appearance = theme.settingsAppearance;
    variantLabel.font = appearance.variantFont;
    variantLabel.textColor = appearance.variantColor;
}

static const void *LGSettingsCellBakedIconKey = &LGSettingsCellBakedIconKey;

static bool LGSettingsCellIsBakedIcon(UIImage *image)
{
    return image != nil && objc_getAssociatedObject(image, LGSettingsCellBakedIconKey) != nil;
}

static UIImage *LGSettingsCellBakedShadowIcon(UIImage *image, LGSettingsAppearance *appearance)
{
    if (LGSettingsCellIsBakedIcon(image))
        return image;
    CGSize imageSize = image.size;
    CGFloat side = appearance.iconSize;
    if (imageSize.width < 1.0f || imageSize.height < 1.0f || side < 1.0f || appearance.shadowColor == nil)
        return nil;

    static NSMutableDictionary *cache = nil;
    if (cache == nil)
        cache = [[NSMutableDictionary alloc] init];
    CGSize offset = appearance.iconShadowOffset;
    NSString *key = [[NSString alloc] initWithFormat:@"%p:%.2f:%p:%.3f:%.2f:%.2f:%.2f", image, side, appearance.shadowColor, appearance.iconShadowOpacity, appearance.iconShadowRadius, offset.width, offset.height];
    NSArray *entry = cache[key];
    if (entry != nil)
        return entry[1];

    CGFloat fit = MIN(side / imageSize.width, side / imageSize.height);
    CGFloat margin = ceilf((appearance.iconShadowRadius * 3.0f + MAX(fabsf(offset.width), fabsf(offset.height)) + 1.0f) / fit);
    CGFloat sourceScale = image.scale > 0.0f ? image.scale : 1.0f;

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(imageSize.width + margin * 2.0f, imageSize.height + margin * 2.0f), false, sourceScale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIImage *drawn = nil;
    if (context != NULL)
    {
        UIColor *shadowColor = [appearance.shadowColor colorWithAlphaComponent:CGColorGetAlpha(appearance.shadowColor.CGColor) * appearance.iconShadowOpacity];
        CGContextSetShadowWithColor(context, CGSizeMake(offset.width * sourceScale / fit, offset.height * sourceScale / fit), appearance.iconShadowRadius * 1.35f * sourceScale / fit, shadowColor.CGColor);
        [image drawInRect:CGRectMake(margin, margin, imageSize.width, imageSize.height)];
        drawn = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();
    if (drawn.CGImage == NULL)
        return nil;
    UIImage *result = [UIImage imageWithCGImage:drawn.CGImage scale:sourceScale / fit orientation:UIImageOrientationUp];
    if (result == nil)
        return nil;
    objc_setAssociatedObject(result, LGSettingsCellBakedIconKey, @true, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (cache.count > 64)
        [cache removeAllObjects];
    cache[key] = @[image, result];
    return result;
}

+ (void)applyLegacyBrandedIconStyleWithTheme:(LGTheme *)theme iconView:(UIImageView *)iconView
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];
    [self applyLegacyBrandedIconStyleWithAppearance:theme.settingsAppearance iconView:iconView];
}

+ (void)applyLegacyBrandedIconStyleWithAppearance:(LGSettingsAppearance *)appearance iconView:(UIImageView *)iconView
{
    if (iconView == nil || appearance == nil)
        return;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    if (LGPlatformLayerSupportsShadow(iconView.layer))
    {
        UIImage *baked = iconView.image == nil ? nil : LGSettingsCellBakedShadowIcon(iconView.image, appearance);
        if (baked != nil)
        {
            iconView.image = baked;
            iconView.contentMode = UIViewContentModeCenter;
            LGPlatformSetLayerShadow(iconView.layer, nil, 0.0f, 0.0f, CGSizeZero);
        }
        else
            LGPlatformSetLayerShadow(iconView.layer, appearance.shadowColor, appearance.iconShadowOpacity, appearance.iconShadowRadius, appearance.iconShadowOffset);
    }
    else if (iconView.image != nil)
        iconView.image = LGPlatformImageWithShadow(iconView.image, appearance.shadowColor, appearance.iconShadowOpacity, appearance.iconShadowRadius, appearance.iconShadowOffset);
}

+ (void)applyLegacyBrandedStyleWithTheme:(LGTheme *)theme titleLabel:(UILabel *)titleLabel iconView:(UIImageView *)iconView disclosureView:(UIImageView *)disclosureView bounds:(CGRect)bounds safeAreaInsets:(UIEdgeInsets)safeAreaInsets
{
    if (theme == nil)
        theme = [LGTheme brandedTheme];

    [self applyLegacyBrandedTitleStyleWithTheme:theme titleLabel:titleLabel];

    if (disclosureView != nil)
        disclosureView.image = [self legacyBrandedDisclosureImageWithTheme:theme];

    CGSize disclosureSize = disclosureView == nil ? CGSizeZero : disclosureView.frame.size;
    if (disclosureView != nil && disclosureView.image != nil)
        disclosureSize = disclosureView.image.size;

    LGSettingsCellLegacyLayout layout;
    LGSettingsCellGetLegacyBrandedLayout(theme, bounds, safeAreaInsets, disclosureSize, disclosureView == nil ? LGSettingsCellAccessoryNone : LGSettingsCellAccessoryDisclosure, CGSizeZero, 0.0f, theme.settingsAppearance.titleTrailingSpacing, &layout);
    titleLabel.frame = layout.titleFrame;

    if (iconView != nil)
    {
        iconView.contentMode = LGSettingsCellIsBakedIcon(iconView.image) ? UIViewContentModeCenter : UIViewContentModeScaleAspectFit;
        iconView.frame = layout.iconFrame;
    }

    if (disclosureView != nil)
        disclosureView.frame = layout.accessoryFrame;
}

@end
