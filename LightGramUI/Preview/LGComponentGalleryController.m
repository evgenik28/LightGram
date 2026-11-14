#import "LGComponentGalleryController.h"
#import "../Core/LGTheme.h"
#import "../Core/LGPalette.h"
#import "../Core/LGMetrics.h"
#import "../Common/LGBadgeView.h"
#import "../Common/LGPresenceView.h"
#import "../Lists/LGSettingsCell.h"
#import "../Lists/LGContactCell.h"
#import "../Lists/LGDialogCell.h"
#import "LGPreviewData.h"

@implementation LGComponentGalleryController
- (void)loadView
{
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    LGTheme *theme = [LGTheme brandedTheme];
    scrollView.backgroundColor = theme.palette.backgroundColor;

    CGFloat width = 320.0f;
    CGFloat y = 18.0f;
    NSArray *counts = [LGPreviewData badgeCounts];
    for (NSNumber *number in counts)
    {
        LGBadgeView *badge = [[LGBadgeView alloc] initWithFrame:CGRectZero];
        badge.theme = theme;
        badge.count = [number integerValue];
        CGSize size = [badge sizeThatFits:CGSizeMake(120.0f, theme.metrics.badgeHeight)];
        badge.frame = CGRectMake(20.0f, y, size.width, size.height);
        [scrollView addSubview:badge];
        y += 28.0f;
    }

    LGSettingsCell *settings = [[LGSettingsCell alloc] initWithFrame:CGRectMake(0.0f, y + 8.0f, width, theme.metrics.settingsRowHeight)];
    settings.theme = theme;
    settings.titleLabel.text = @"Settings Cell";
    settings.showsIcon = YES;
    settings.showsAccessory = YES;
    [scrollView addSubview:settings];
    y = CGRectGetMaxY(settings.frame) + 10.0f;

    LGContactCell *contact = [[LGContactCell alloc] initWithFrame:CGRectMake(0.0f, y, width, 56.0f)];
    contact.theme = theme;
    contact.titleLabel.text = @"Contact";
    contact.subtitleLabel.text = @"Online";
    [scrollView addSubview:contact];
    y = CGRectGetMaxY(contact.frame) + 10.0f;

    LGDialogCell *dialog = [[LGDialogCell alloc] initWithFrame:CGRectMake(0.0f, y, width, theme.metrics.dialogRowHeight)];
    dialog.theme = theme;
    dialog.titleLabel.text = @"Saved Messages";
    dialog.subtitleLabel.text = @"LightGram UI Kit preview";
    dialog.detailLabel.text = @"22:41";
    dialog.badgeView.count = 42;
    [scrollView addSubview:dialog];
    y = CGRectGetMaxY(dialog.frame) + 24.0f;

    scrollView.contentSize = CGSizeMake(width, y);
    self.view = scrollView;
}
@end
