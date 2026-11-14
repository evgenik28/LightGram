#import "LGNavigationButton.h"
#import "../Core/LGTheme.h"
#import "../Core/LGTypography.h"
#import "../Core/LGNavigationAppearance.h"

@implementation LGNavigationButton
- (void)applyTheme
{
    [super applyTheme];
    LGNavigationAppearance *appearance = self.theme.navigationAppearance;
    self.titleLabel.font = appearance.buttonFont;
    [self setTitleColor:appearance.buttonTitleColor forState:UIControlStateNormal];
    [self setTitleColor:[appearance.buttonTitleColor colorWithAlphaComponent:appearance.buttonHighlightedAlpha] forState:UIControlStateHighlighted];
    self.titleLabel.shadowColor = appearance.buttonShadowColor;
    self.titleLabel.shadowOffset = CGSizeMake(appearance.buttonShadowOffset.horizontal, appearance.buttonShadowOffset.vertical);
}
@end
