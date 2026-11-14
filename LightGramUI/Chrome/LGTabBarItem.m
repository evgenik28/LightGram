#import "LGTabBarItem.h"
#import "../Common/LGBadgeView.h"
#import "../Core/LGTheme.h"
#import "../Core/LGMetrics.h"
#import "../Core/LGGeometry.h"

@implementation LGTabBarItem
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _badgeView = [[LGBadgeView alloc] initWithFrame:CGRectZero];
        [self addSubview:_badgeView];
    }
    return self;
}

- (void)setTheme:(LGTheme *)theme
{
    [super setTheme:theme];
    _badgeView.theme = self.theme;
}

- (void)setBadgeCount:(NSInteger)badgeCount
{
    _badgeCount = badgeCount;
    _badgeView.count = badgeCount;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (_badgeCount <= 0)
        return;
    CGSize size = [_badgeView sizeThatFits:CGSizeMake(80.0f, self.theme.metrics.badgeHeight)];
    CGFloat x = LGPixelFloor(self.bounds.size.width * 0.5f + 7.0f);
    _badgeView.frame = CGRectMake(x, 2.0f, size.width, size.height);
}
@end
