#import "LGMessageContentView.h"
@implementation LGMessageContentView
- (void)setItem:(id)item
{
    _item = item;
    [self setNeedsLayout];
    [self setNeedsDisplay];
}
- (CGSize)contentSizeThatFits:(CGSize)size
{
    return size;
}
@end
