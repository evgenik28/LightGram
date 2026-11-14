#import "LGLabel.h"
#import "../Core/LGTheme.h"
#import "../Core/LGPalette.h"
#import "../Core/LGTypography.h"

@implementation LGLabel
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _theme = [LGTheme currentTheme];
        self.backgroundColor = [UIColor clearColor];
        [self applyTheme];
    }
    return self;
}

- (void)setTheme:(LGTheme *)theme
{
    _theme = theme == nil ? [LGTheme currentTheme] : theme;
    [self applyTheme];
    [self setNeedsDisplay];
}

- (void)applyTheme
{
    self.textColor = _theme.palette.primaryTextColor;
    self.font = _theme.typography.bodyFont;
}
@end
