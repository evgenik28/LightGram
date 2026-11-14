#import "LGButton.h"
#import "../Core/LGTheme.h"
#import "../Core/LGPalette.h"
#import "../Core/LGTypography.h"
#import "../Core/LGAssets.h"
#import "../../LightGramPlatform/LGPlatformUIKit.h"

@implementation LGButton
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _theme = [LGTheme currentTheme];
        LGPlatformSetExclusiveTouch(self, YES);
        [self applyTheme];
    }
    return self;
}

- (void)setTheme:(LGTheme *)theme
{
    _theme = theme == nil ? [LGTheme currentTheme] : theme;
    [self applyTheme];
}

- (void)setNormalAssetName:(NSString *)normalAssetName
{
    _normalAssetName = [normalAssetName copy];
    [self setBackgroundImage:[_theme.assets imageNamed:_normalAssetName] forState:UIControlStateNormal];
}

- (void)setHighlightedAssetName:(NSString *)highlightedAssetName
{
    _highlightedAssetName = [highlightedAssetName copy];
    [self setBackgroundImage:[_theme.assets imageNamed:_highlightedAssetName] forState:UIControlStateHighlighted];
}

- (void)applyTheme
{
    [self setTitleColor:_theme.palette.primaryTextColor forState:UIControlStateNormal];
    [self setTitleColor:[_theme.palette.primaryTextColor colorWithAlphaComponent:0.55f] forState:UIControlStateDisabled];
    self.titleLabel.font = _theme.typography.bodyFont;
    if ([_normalAssetName length] != 0)
        [self setBackgroundImage:[_theme.assets imageNamed:_normalAssetName] forState:UIControlStateNormal];
    if ([_highlightedAssetName length] != 0)
        [self setBackgroundImage:[_theme.assets imageNamed:_highlightedAssetName] forState:UIControlStateHighlighted];
}
@end
