#import "LGCallCell.h"
@implementation LGCallCell
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.showsAvatar = YES;
        self.showsAccessory = YES;
    }
    return self;
}
@end
