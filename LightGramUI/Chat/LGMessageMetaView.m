#import "LGMessageMetaView.h"
#import "../Base/LGLabel.h"
#import "../Common/LGCheckmarkView.h"
#import "../Core/LGTheme.h"
#import "../Core/LGPalette.h"
#import "../Core/LGTypography.h"
#import "../Core/LGGeometry.h"

@implementation LGMessageMetaView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        _viewsLabel = [[LGLabel alloc] initWithFrame:CGRectZero];
        _timeLabel = [[LGLabel alloc] initWithFrame:CGRectZero];
        _checkmarkView = [[LGCheckmarkView alloc] initWithFrame:CGRectZero];
        [self addSubview:_viewsLabel];
        [self addSubview:_timeLabel];
        [self addSubview:_checkmarkView];
        [self applyTheme];
    }
    return self;
}

- (void)setTheme:(LGTheme *)theme
{
    [super setTheme:theme];
    _viewsLabel.theme = self.theme;
    _timeLabel.theme = self.theme;
    _checkmarkView.theme = self.theme;
    [self applyTheme];
}

- (void)applyTheme
{
    self.backgroundColor = [UIColor clearColor];
    _viewsLabel.font = self.theme.typography.messageMetaFont;
    _timeLabel.font = self.theme.typography.messageMetaFont;
    _viewsLabel.textColor = self.theme.palette.messageMetaColor;
    _timeLabel.textColor = self.theme.palette.messageMetaColor;
}

- (void)setTimeText:(NSString *)timeText
{
    _timeText = [timeText copy];
    _timeLabel.text = _timeText;
    [self setNeedsLayout];
}

- (void)setViewsText:(NSString *)viewsText
{
    _viewsText = [viewsText copy];
    _viewsLabel.text = _viewsText;
    [self setNeedsLayout];
}

- (void)setDeliveryState:(LGDeliveryState)deliveryState
{
    _deliveryState = deliveryState;
    _checkmarkView.hidden = !_outgoing || deliveryState < LGDeliveryStateSent || deliveryState == LGDeliveryStateFailed;
    _checkmarkView.alpha = deliveryState == LGDeliveryStateRead ? 1.0f : 0.62f;
    [self setNeedsLayout];
}

- (void)setOutgoing:(BOOL)outgoing
{
    _outgoing = outgoing;
    [self setDeliveryState:_deliveryState];
}

- (CGSize)sizeThatFits:(CGSize)size
{
    CGSize timeSize = [_timeLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, size.height)];
    CGSize viewsSize = [_viewsLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, size.height)];
    CGFloat check = _checkmarkView.hidden ? 0.0f : 14.0f;
    CGFloat spacing = [_viewsText length] == 0 ? 0.0f : 5.0f;
    return CGSizeMake(ceilf(timeSize.width + viewsSize.width + check + spacing + (check > 0.0f ? 3.0f : 0.0f)), MAX(15.0f, MAX(timeSize.height, viewsSize.height)));
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat x = 0.0f;
    if ([_viewsText length] != 0)
    {
        CGSize size = [_viewsLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, self.bounds.size.height)];
        _viewsLabel.hidden = NO;
        _viewsLabel.frame = CGRectMake(x, LGPixelFloor((self.bounds.size.height - size.height) * 0.5f), ceilf(size.width), size.height);
        x = CGRectGetMaxX(_viewsLabel.frame) + 5.0f;
    }
    else
    {
        _viewsLabel.hidden = YES;
    }

    CGSize timeSize = [_timeLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, self.bounds.size.height)];
    _timeLabel.frame = CGRectMake(x, LGPixelFloor((self.bounds.size.height - timeSize.height) * 0.5f), ceilf(timeSize.width), timeSize.height);
    x = CGRectGetMaxX(_timeLabel.frame);

    if (!_checkmarkView.hidden)
        _checkmarkView.frame = CGRectMake(x + 3.0f, LGPixelFloor((self.bounds.size.height - 11.0f) * 0.5f), 12.0f, 11.0f);
}
@end
