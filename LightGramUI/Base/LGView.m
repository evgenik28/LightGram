#import "LGView.h"
#import "../Core/LGTheme.h"
#import "../Core/LGPalette.h"

@implementation LGView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _theme = [LGTheme currentTheme];
        [self applyTheme];
    }
    return self;
}

- (void)setTheme:(LGTheme *)theme
{
    _theme = theme == nil ? [LGTheme currentTheme] : theme;
    [self applyTheme];
    [self setNeedsLayout];
    [self setNeedsDisplay];
}

- (void)applyTheme
{
    self.backgroundColor = _theme.palette.backgroundColor;
}
@end
