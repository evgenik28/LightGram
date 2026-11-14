#import "LGBackgroundView.h"
#import "../Core/LGTheme.h"
#import "../Core/LGAssets.h"

@implementation LGBackgroundView
- (void)setAssetName:(NSString *)assetName
{
    _assetName = [assetName copy];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    UIImage *image = [self.theme.assets imageNamed:_assetName];
    if (image != nil)
        [image drawInRect:self.bounds];
    else
        [super drawRect:rect];
}
@end
