#import "LGActionCell.h"
#import "../Core/LGTheme.h"
#import "../Core/LGPalette.h"
#import "../Base/LGLabel.h"

@implementation LGActionCell
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.showsAvatar = NO;
        self.showsIcon = NO;
        self.showsAccessory = NO;
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
    }
    return self;
}

- (void)applyTheme
{
    [super applyTheme];
    self.titleLabel.textColor = self.theme.palette.accentColor;
}
@end
