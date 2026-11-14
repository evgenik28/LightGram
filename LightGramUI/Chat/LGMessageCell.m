#import "LGMessageCell.h"
#import "LGBubbleView.h"
#import "LGMessageContentView.h"
#import "LGMessageMetaView.h"
#import "../Core/LGTheme.h"
#import "../Core/LGGeometry.h"

@implementation LGMessageCell
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        _bubbleInsets = UIEdgeInsetsMake(2.0f, 8.0f, 2.0f, 8.0f);
        _contentInsets = UIEdgeInsetsMake(7.0f, 10.0f, 18.0f, 10.0f);
        _bubbleView = [[LGBubbleView alloc] initWithFrame:CGRectZero];
        _metaView = [[LGMessageMetaView alloc] initWithFrame:CGRectZero];
        [self addSubview:_bubbleView];
        [self addSubview:_metaView];
    }
    return self;
}

- (void)setTheme:(LGTheme *)theme
{
    [super setTheme:theme];
    _bubbleView.theme = self.theme;
    _contentView.theme = self.theme;
    _metaView.theme = self.theme;
}

- (void)setAlignment:(LGMessageAlignment)alignment
{
    _alignment = alignment;
    _bubbleView.alignment = alignment;
    _metaView.outgoing = alignment == LGMessageAlignmentOutgoing;
    [self setNeedsLayout];
}

- (void)setContentView:(LGMessageContentView *)contentView
{
    if (_contentView == contentView)
        return;
    [_contentView removeFromSuperview];
    _contentView = contentView;
    if (_contentView != nil)
    {
        _contentView.theme = self.theme;
        [self insertSubview:_contentView aboveSubview:_bubbleView];
    }
    [self bringSubviewToFront:_metaView];
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat maximumBubbleWidth = floorf(self.bounds.size.width * 0.78f);
    CGSize contentSize = _contentView == nil ? CGSizeZero : [_contentView contentSizeThatFits:CGSizeMake(MAX(0.0f, maximumBubbleWidth - _contentInsets.left - _contentInsets.right), CGFLOAT_MAX)];
    CGSize metaSize = [_metaView sizeThatFits:CGSizeMake(maximumBubbleWidth, 18.0f)];
    CGFloat innerWidth = MAX(contentSize.width, metaSize.width);
    CGFloat bubbleWidth = MIN(maximumBubbleWidth, MAX(48.0f, innerWidth + _contentInsets.left + _contentInsets.right));
    CGFloat bubbleHeight = MAX(32.0f, contentSize.height + _contentInsets.top + _contentInsets.bottom);
    CGFloat x = _alignment == LGMessageAlignmentOutgoing ? self.bounds.size.width - _bubbleInsets.right - bubbleWidth : _bubbleInsets.left;
    CGFloat y = _bubbleInsets.top;
    _bubbleView.frame = CGRectMake(x, y, bubbleWidth, bubbleHeight);
    _contentView.frame = CGRectMake(x + _contentInsets.left, y + _contentInsets.top, MAX(0.0f, bubbleWidth - _contentInsets.left - _contentInsets.right), contentSize.height);
    _metaView.frame = CGRectMake(x + bubbleWidth - _contentInsets.right - metaSize.width, y + bubbleHeight - 16.0f, metaSize.width, 14.0f);
}
@end
