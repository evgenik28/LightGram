#import "LGComposerTextView.h"
#import "../../Core/LGTheme.h"
#import "../../Core/LGPalette.h"
#import "../../Core/LGTypography.h"

@implementation LGComposerTextView
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
}

- (void)applyTheme
{
    self.backgroundColor = self.theme.palette.cardColor;
    self.textColor = self.theme.palette.primaryTextColor;
    self.font = self.theme.typography.messageFont;
}
@end
