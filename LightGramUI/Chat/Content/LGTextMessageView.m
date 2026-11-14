#import "LGTextMessageView.h"
#import "../../Base/LGLabel.h"
#import "../../Core/LGTheme.h"
#import "../../Core/LGTypography.h"
#import "../../../LightGramPlatform/LGPlatformText.h"

@implementation LGTextMessageView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        _textLabel = [[LGLabel alloc] initWithFrame:CGRectZero];
        _textLabel.numberOfLines = 0;
        _textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [self addSubview:_textLabel];
        [self applyTheme];
    }
    return self;
}

- (void)setTheme:(LGTheme *)theme
{
    [super setTheme:theme];
    _textLabel.theme = self.theme;
    [self applyTheme];
}

- (void)applyTheme
{
    [super applyTheme];
    self.backgroundColor = [UIColor clearColor];
    _textLabel.font = self.theme.typography.messageFont;
}

- (void)setText:(NSString *)text
{
    _text = [text copy];
    _textLabel.text = _text;
    [self setNeedsLayout];
}

- (CGSize)contentSizeThatFits:(CGSize)size
{
    CGSize measured = LGPlatformTextSize(_text, _textLabel.font, size, UILineBreakModeWordWrap);
    return CGSizeMake(ceilf(measured.width), ceilf(measured.height));
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _textLabel.frame = self.bounds;
}
@end
