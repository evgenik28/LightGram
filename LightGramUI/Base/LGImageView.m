#import "LGImageView.h"
#import "../Core/LGTheme.h"
#import "../Core/LGAssets.h"

@implementation LGImageView
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
    [self applyTheme];
}

- (void)setAssetName:(NSString *)assetName
{
    _assetName = [assetName copy];
    [self reloadAsset];
}

- (void)reloadAsset
{
    self.image = [_theme.assets imageNamed:_assetName];
}

- (void)applyTheme
{
    [self reloadAsset];
}
@end
