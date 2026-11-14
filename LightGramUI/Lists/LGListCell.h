#import "../Base/LGView.h"
#import "../Base/LGIconView.h"
#import "../Base/LGLabel.h"
#import "../Base/LGSeparatorView.h"
#import "../Common/LGAvatarView.h"
#import "../Common/LGBadgeView.h"

@interface LGListCell : LGView
@property (nonatomic, retain, readonly) LGAvatarView *avatarView;
@property (nonatomic, retain, readonly) LGIconView *iconView;
@property (nonatomic, retain, readonly) LGLabel *titleLabel;
@property (nonatomic, retain, readonly) LGLabel *subtitleLabel;
@property (nonatomic, retain, readonly) LGLabel *detailLabel;
@property (nonatomic, retain, readonly) LGBadgeView *badgeView;
@property (nonatomic, retain, readonly) LGIconView *accessoryView;
@property (nonatomic, retain, readonly) LGSeparatorView *separatorView;
@property (nonatomic) UIEdgeInsets contentInsets;
@property (nonatomic) BOOL showsAvatar;
@property (nonatomic) BOOL showsIcon;
@property (nonatomic) BOOL showsAccessory;
@property (nonatomic) BOOL showsSeparator;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
- (void)prepareForReuse;
@end
