#import "../submodules/LegacyComponents/LegacyComponents/TGOverlayController.h"

typedef enum {
    TGLightGramCardPlacementCenter,
    TGLightGramCardPlacementBottom,
    TGLightGramCardPlacementSheet
} TGLightGramCardPlacement;

@class TGLightGramCardOverlay;

@interface TGLightGramCardView : UIView

@property (nonatomic, weak, readonly) TGLightGramCardOverlay *overlay;

- (CGFloat)heightForWidth:(CGFloat)width;
- (CGFloat)heightForWidth:(CGFloat)width availableHeight:(CGFloat)availableHeight;
- (void)cardWillAppear;
- (void)cardDidDisappear;

@end

@interface TGLightGramCardOverlay : TGOverlayController

@property (nonatomic, readonly) TGLightGramCardView *cardView;
@property (nonatomic, readonly) TGLightGramCardPlacement placement;
@property (nonatomic) bool dismissesOnDimTap;
@property (nonatomic, copy) void (^onDismiss)(void);

@property (nonatomic, weak, readonly) UIViewController *parentController;

+ (TGLightGramCardOverlay *)presentCardView:(TGLightGramCardView *)cardView placement:(TGLightGramCardPlacement)placement;
+ (TGLightGramCardOverlay *)presentCardView:(TGLightGramCardView *)cardView placement:(TGLightGramCardPlacement)placement parentController:(UIViewController *)parentController;

- (void)setNeedsCardLayoutAnimated:(bool)animated;
- (void)dismissAnimated:(bool)animated completion:(void (^)(void))completion;

@end
