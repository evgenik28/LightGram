#import <UIKit/UIKit.h>

@class LGAssets;
@class LGSurfaceStyle;
@class LGSurfaceShadow;

@interface LGSurfaceRenderer : NSObject
- (instancetype)initWithAssets:(LGAssets *)assets;
- (UIImage *)imageWithStyle:(LGSurfaceStyle *)style size:(CGSize)size bodyFrame:(CGRect)bodyFrame;
- (UIImage *)glyphImageWithTemplate:(UIImage *)image opticalSize:(CGFloat)opticalSize;
- (UIImage *)glyphImageWithText:(NSString *)text font:(UIFont *)font opticalSize:(CGFloat)opticalSize;
- (UIImage *)iconImageWithTemplate:(UIImage *)image gradientColors:(NSArray *)colors locations:(NSArray *)locations shadow:(LGSurfaceShadow *)shadow outsets:(UIEdgeInsets)outsets;
- (UIImage *)iconImageWithTemplate:(UIImage *)image gradientColors:(NSArray *)colors locations:(NSArray *)locations shadows:(NSArray *)shadows outsets:(UIEdgeInsets)outsets;
@end
