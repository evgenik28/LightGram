#import "LGGroupedCard.h"
#import "../Core/LGTheme.h"
#import "../Core/LGPalette.h"
#import "../../LightGramPlatform/LGPlatformGraphics.h"

@implementation LGGroupedCard
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        _cornerRadius = 9.0f;
    }
    return self;
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    _cornerRadius = MAX(0.0f, cornerRadius);
    [self setNeedsDisplay];
}

- (void)applyTheme
{
    self.backgroundColor = [UIColor clearColor];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    LGPlatformAddRoundedRectPath(context, CGRectInset(self.bounds, 0.5f, 0.5f), _cornerRadius);
    CGContextSetFillColorWithColor(context, [self.theme.palette.cardColor CGColor]);
    CGContextFillPath(context);
}
@end
