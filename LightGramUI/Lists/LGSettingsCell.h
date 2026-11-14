#import "LGListCell.h"

@class LGTheme;
@class LGSettingsAppearance;

typedef enum {
    LGSettingsCellAccessoryNone = 0,
    LGSettingsCellAccessoryDisclosure = 1,
    LGSettingsCellAccessoryControl = 2
} LGSettingsCellAccessoryKind;

typedef enum {
    LGGroupedCellPositionSingle = 0,
    LGGroupedCellPositionTop = 1,
    LGGroupedCellPositionMiddle = 2,
    LGGroupedCellPositionBottom = 3
} LGGroupedCellPosition;

typedef struct {
    CGRect iconFrame;
    CGRect titleFrame;
    CGRect accessoryFrame;
    CGRect trailingFrame;
} LGSettingsCellLegacyLayout;

FOUNDATION_EXPORT void LGSettingsCellGetLegacyLayout(LGSettingsAppearance *appearance, CGRect bounds, UIEdgeInsets safeAreaInsets, CGSize accessorySize, LGSettingsCellAccessoryKind accessoryKind, CGSize trailingSize, CGFloat trailingVerticalOffset, CGFloat titleTrailingSpacing, LGSettingsCellLegacyLayout *layout);
FOUNDATION_EXPORT void LGSettingsCellGetLegacyBrandedLayout(LGTheme *theme, CGRect bounds, UIEdgeInsets safeAreaInsets, CGSize accessorySize, LGSettingsCellAccessoryKind accessoryKind, CGSize trailingSize, CGFloat trailingVerticalOffset, CGFloat titleTrailingSpacing, LGSettingsCellLegacyLayout *layout);

@interface LGSettingsCell : LGListCell
+ (UIImage *)legacyBrandedIconNamed:(NSString *)name theme:(LGTheme *)theme;
+ (UIImage *)legacyBrandedIconNamed:(NSString *)name appearance:(LGSettingsAppearance *)appearance theme:(LGTheme *)theme;
+ (UIImage *)legacyBrandedDisclosureImageWithTheme:(LGTheme *)theme;
+ (UIImage *)legacyGroupedBackgroundImageForPosition:(LGGroupedCellPosition)position selected:(BOOL)selected theme:(LGTheme *)theme;
+ (BOOL)legacyGroupedBackgroundUsesSurfaceWithTheme:(LGTheme *)theme;
+ (UIImage *)legacyGroupedSurfaceImageForPosition:(LGGroupedCellPosition)position selected:(BOOL)selected size:(CGSize)size theme:(LGTheme *)theme outsets:(UIEdgeInsets *)outsets;
+ (UIImage *)legacyGroupedSurfaceImageForPosition:(LGGroupedCellPosition)position selected:(BOOL)selected size:(CGSize)size appearance:(LGSettingsAppearance *)appearance theme:(LGTheme *)theme outsets:(UIEdgeInsets *)outsets;
+ (UIColor *)legacyScreenBackgroundColorWithTheme:(LGTheme *)theme;
+ (UIColor *)legacyCollectionBackgroundColorWithTheme:(LGTheme *)theme;
+ (void)applyLegacyBrandedTitleStyleWithTheme:(LGTheme *)theme titleLabel:(UILabel *)titleLabel;
+ (void)applyLegacyBrandedTitleStyleWithAppearance:(LGSettingsAppearance *)appearance titleLabel:(UILabel *)titleLabel;
+ (BOOL)applyLegacyBrandedHeaderStyleWithTheme:(LGTheme *)theme headerLabel:(UILabel *)headerLabel;
+ (void)applyLegacyBrandedVariantStyleWithTheme:(LGTheme *)theme variantLabel:(UILabel *)variantLabel;
+ (void)applyLegacyBrandedIconStyleWithTheme:(LGTheme *)theme iconView:(UIImageView *)iconView;
+ (void)applyLegacyBrandedIconStyleWithAppearance:(LGSettingsAppearance *)appearance iconView:(UIImageView *)iconView;
+ (void)applyLegacyBrandedStyleWithTheme:(LGTheme *)theme titleLabel:(UILabel *)titleLabel iconView:(UIImageView *)iconView disclosureView:(UIImageView *)disclosureView bounds:(CGRect)bounds safeAreaInsets:(UIEdgeInsets)safeAreaInsets;
@end
