#import "../Base/LGView.h"

@class LGTheme;

@interface LGProfileHeader : LGView
+ (UIImage *)legacyCardImageWithTheme:(LGTheme *)theme size:(CGSize)size hasMusic:(BOOL)hasMusic outsets:(UIEdgeInsets *)outsets;
+ (UIImage *)legacyAvatarOverlayImageWithTheme:(LGTheme *)theme size:(CGSize)size outsets:(UIEdgeInsets *)outsets;
+ (UIImage *)legacyStatusBackgroundImageWithTheme:(LGTheme *)theme size:(CGSize)size outsets:(UIEdgeInsets *)outsets;
+ (UIImage *)legacyMusicPlayImageWithTheme:(LGTheme *)theme outsets:(UIEdgeInsets *)outsets;
+ (UIFont *)legacyNameFontWithTheme:(LGTheme *)theme size:(CGFloat)size;
+ (void)applyLegacyAvatarStyleWithTheme:(LGTheme *)theme view:(UIView *)view;
+ (void)applyLegacyReflectionStyleWithTheme:(LGTheme *)theme imageView:(UIImageView *)imageView;
@end
