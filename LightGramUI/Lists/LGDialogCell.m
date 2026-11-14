#import "LGDialogCell.h"
#import "../Core/LGTheme.h"
#import "../Core/LGTypography.h"
#import "../Base/LGLabel.h"

@implementation LGDialogCell
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
        self.showsAvatar = YES;
    return self;
}

- (void)applyTheme
{
    [super applyTheme];
    self.titleLabel.font = self.theme.typography.dialogTitleFont;
    self.subtitleLabel.font = self.theme.typography.dialogPreviewFont;
    self.detailLabel.font = self.theme.typography.dialogDateFont;
}
@end
