#import <UIKit/UIKit.h>

#import "TGPresentationCustomColors.h"

@class TGPresentationPallete;

FOUNDATION_EXPORT CGFloat TGLightGramColorPreviewHeight(TGPresentationColorPreview preview);
FOUNDATION_EXPORT UIImage *TGLightGramColorPreviewImage(TGPresentationColorPreview preview, TGPresentationPallete *pallete, UIColor *color, CGSize size);
FOUNDATION_EXPORT UIImage *TGLightGramColorSwatchImage(UIColor *color, CGFloat diameter, UIColor *borderColor);
FOUNDATION_EXPORT void TGLightGramColorGetHSB(UIColor *color, CGFloat *hue, CGFloat *saturation, CGFloat *brightness);
FOUNDATION_EXPORT NSString *TGLightGramColorHexString(UIColor *color);
