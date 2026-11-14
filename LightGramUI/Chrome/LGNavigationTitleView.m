#import "LGNavigationTitleView.h"
#import "../Core/LGTheme.h"
#import "../Core/LGNavigationAppearance.h"
#import "../../LightGramPlatform/LGPlatformUIKit.h"

@interface LGNavigationTitleView ()
{
    CGFloat _verticalOffset;
}
@end

@implementation LGNavigationTitleView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.opaque = NO;
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.numberOfLines = 1;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_titleLabel];
        [self applyTheme];
    }
    return self;
}

- (void)applyTheme
{
    LGNavigationAppearance *appearance = self.theme.navigationAppearance;
    self.backgroundColor = [UIColor clearColor];
    _titleLabel.font = appearance.titleFont;
    _titleLabel.textColor = appearance.titleColor;
    _titleLabel.shadowColor = appearance.titleShadowColor;
    _titleLabel.shadowOffset = CGSizeMake(appearance.titleShadowOffset.horizontal, appearance.titleShadowOffset.vertical);
    _verticalOffset = appearance.titleViewVerticalOffset;
    [self updateTitleLayout];
}

- (NSString *)title
{
    return _titleLabel.text;
}

- (BOOL)accessibilityActivate
{
    return _accessibilityActivation != nil ? _accessibilityActivation() : NO;
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
    [self updateTitleLayout];
}

- (void)updateTitleLayout
{
    LGPlatformInvalidateViewIntrinsicContentSize(self);
    [self setNeedsLayout];
    [self.superview setNeedsLayout];
}

- (CGSize)titleSize
{
    CGSize size = [_titleLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    return CGSizeMake(ceil(size.width), ceil(size.height));
}

- (CGSize)sizeThatFits:(CGSize)__unused size
{
    CGSize titleSize = [self titleSize];
    return CGSizeMake(titleSize.width, titleSize.height + fabs(_verticalOffset) * 2.0f);
}

- (CGSize)intrinsicContentSize
{
    return [self sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGSize bounds = self.bounds.size;
    CGSize titleSize = [self titleSize];
    CGFloat width = MIN(titleSize.width, bounds.width);
    _titleLabel.frame = CGRectMake(floor((bounds.width - width) / 2.0f), (bounds.height - titleSize.height) / 2.0f + _verticalOffset, width, titleSize.height);
}

@end
