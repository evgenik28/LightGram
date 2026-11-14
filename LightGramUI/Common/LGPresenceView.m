#import "LGPresenceView.h"
#import "../Core/LGTheme.h"
#import "../Core/LGPalette.h"
#import "../Core/LGMetrics.h"

@implementation LGPresenceView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
        self.backgroundColor = [UIColor clearColor];
    return self;
}

- (void)setPresenceState:(LGPresenceState)presenceState
{
    _presenceState = presenceState;
    self.hidden = presenceState != LGPresenceStateOnline;
    [self setNeedsDisplay];
}

- (void)applyTheme
{
    self.backgroundColor = [UIColor clearColor];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGRect circle = CGRectInset(self.bounds, self.theme.metrics.pixel, self.theme.metrics.pixel);
    [self.theme.palette.cardColor setFill];
    UIRectFill(CGRectZero);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [self.theme.palette.cardColor CGColor]);
    CGContextFillEllipseInRect(context, self.bounds);
    CGContextSetFillColorWithColor(context, [self.theme.palette.presenceOnlineColor CGColor]);
    CGContextFillEllipseInRect(context, circle);
}
@end
