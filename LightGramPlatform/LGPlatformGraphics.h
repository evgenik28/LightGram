#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <stdint.h>

FOUNDATION_EXPORT CGFloat LGPlatformPixelFloor(CGFloat value);
FOUNDATION_EXPORT CGFloat LGPlatformPixelCeil(CGFloat value);
FOUNDATION_EXPORT CGFloat LGPlatformPixelRound(CGFloat value);
FOUNDATION_EXPORT BOOL LGPlatformLayerSupportsShadow(CALayer *layer);
FOUNDATION_EXPORT void LGPlatformSetLayerShadow(CALayer *layer, UIColor *color, CGFloat opacity, CGFloat radius, CGSize offset);
FOUNDATION_EXPORT BOOL LGPlatformGetLayerShadow(CALayer *layer, CGColorRef *color, CGFloat *opacity, CGFloat *radius, CGSize *offset);
FOUNDATION_EXPORT void LGPlatformSetLayerRasterization(CALayer *layer, BOOL rasterize, CGFloat scale);
FOUNDATION_EXPORT void LGPlatformApplyViewShadow(UIView *view, UIColor *color, CGFloat opacity, CGFloat radius, CGSize offset);
FOUNDATION_EXPORT void LGPlatformApplyRoundedViewShadow(UIView *view, UIColor *color, CGFloat opacity, CGFloat radius, CGSize offset, CGFloat cornerRadius);
FOUNDATION_EXPORT UIImage *LGPlatformImageWithShadow(UIImage *image, UIColor *color, CGFloat opacity, CGFloat radius, CGSize offset);
FOUNDATION_EXPORT void LGPlatformAddRoundedRectPath(CGContextRef context, CGRect rect, CGFloat radius);
FOUNDATION_EXPORT UIImage *LGPlatformRenderImage(CGSize size, CGFloat scale, BOOL opaque, void (^drawing)(CGContextRef context));
FOUNDATION_EXPORT void LGPlatformDrawImageInRect(CGContextRef context, UIImage *image, CGRect rect);
FOUNDATION_EXPORT void LGPlatformDrawVerticalGradient(CGContextRef context, CGRect rect, UIColor *topColor, UIColor *bottomColor);
FOUNDATION_EXPORT UIImage *LGPlatformImageFromData(NSData *data);
FOUNDATION_EXPORT UIImage *LGPlatformThumbnailFromImageData(NSData *data, CGSize maximumSize);
FOUNDATION_EXPORT UIImage *LGPlatformDecodeImageData(NSData *data, CGSize maximumPixelSize, NSInteger priority, bool (^isCancelled)(void));
FOUNDATION_EXPORT UIImage *LGPlatformDecodeImageWithBlock(UIImage *(^decode)(void), CGSize maximumPixelSize, NSInteger priority, bool (^isCancelled)(void));
FOUNDATION_EXPORT uint64_t LGPlatformActiveImageDecodes(void);
FOUNDATION_EXPORT uint64_t LGPlatformCachedGraphicsBytes(void);
FOUNDATION_EXPORT void LGPlatformTrimGraphicsCacheToCost(NSUInteger bytes);
FOUNDATION_EXPORT UIImage *LGPlatformThumbnailFromImageFile(NSString *path, size_t maximumPixelSize);
FOUNDATION_EXPORT CGSize LGPlatformImagePixelSizeFromData(NSData *data);
FOUNDATION_EXPORT NSData *LGPlatformJPEGRepresentation(UIImage *image, CGFloat quality);
FOUNDATION_EXPORT BOOL LGPlatformWriteJPEGRepresentationToFile(UIImage *image, CGFloat quality, NSString *path);

typedef struct
{
    void *data;
    size_t width;
    size_t height;
    size_t rowBytes;
} LGPlatformARGB8888Buffer;

FOUNDATION_EXPORT BOOL LGPlatformBoxConvolveARGB8888(const LGPlatformARGB8888Buffer *source, LGPlatformARGB8888Buffer *destination, size_t kernelWidth, size_t kernelHeight);
FOUNDATION_EXPORT BOOL LGPlatformSaturateBGRA8888(const LGPlatformARGB8888Buffer *source, LGPlatformARGB8888Buffer *destination, CGFloat saturation);
