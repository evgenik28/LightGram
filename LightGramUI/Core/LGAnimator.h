#import <UIKit/UIKit.h>

typedef void (^LGAnimationBlock)(void);

@interface LGAnimator : NSObject
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(LGAnimationBlock)animations;
+ (void)animateWithDuration:(NSTimeInterval)duration curve:(UIViewAnimationCurve)curve animations:(LGAnimationBlock)animations;
+ (void)setFrame:(CGRect)frame forView:(UIView *)view duration:(NSTimeInterval)duration;
+ (void)setAlpha:(CGFloat)alpha forView:(UIView *)view duration:(NSTimeInterval)duration;
+ (void)setTransform:(CGAffineTransform)transform forView:(UIView *)view duration:(NSTimeInterval)duration;
@end
