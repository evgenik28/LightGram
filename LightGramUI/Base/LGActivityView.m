#import "LGActivityView.h"
#import "../Core/LGTheme.h"

@implementation LGActivityView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
        _theme = [LGTheme currentTheme];
    return self;
}

- (void)setTheme:(LGTheme *)theme
{
    _theme = theme == nil ? [LGTheme currentTheme] : theme;
}
@end
