#import "TGLightGramAvatarPreviewCollectionItem.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"

#import "TGCollectionItemView.h"

static const CGFloat TGLightGramAvatarPreviewSide = 52.0f;
static const NSUInteger TGLightGramAvatarPreviewCount = 4;

@interface TGLightGramAvatarPreviewCollectionItemView : TGCollectionItemView
{
    NSArray *_avatarViews;
}

- (void)refreshRoundness;

@end

@implementation TGLightGramAvatarPreviewCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        NSMutableArray *avatarViews = [[NSMutableArray alloc] init];
        for (NSUInteger index = 0; index < TGLightGramAvatarPreviewCount; index++)
        {
            TGLetteredAvatarView *avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, TGLightGramAvatarPreviewSide, TGLightGramAvatarPreviewSide)];
            [avatarView setSingleFontSize:20.0f doubleFontSize:20.0f useBoldFont:false];
            avatarView.fadeTransition = false;
            avatarView.layer.cornerRadius = 7.0f;
            [self addSubview:avatarView];
            [avatarViews addObject:avatarView];
        }
        _avatarViews = avatarViews;
        [self reloadAvatars];
    }
    return self;
}

- (void)reloadAvatars
{
    NSArray *firstNames = @[@"Anna", @"Boris", @"Vera", @"Gleb"];
    NSArray *lastNames = @[@"Smith", @"Ivanov", @"Lee", @"Orlov"];
    [_avatarViews enumerateObjectsUsingBlock:^(TGLetteredAvatarView *avatarView, NSUInteger index, __unused BOOL *stop)
    {
        [avatarView loadUserPlaceholderWithSize:CGSizeMake(TGLightGramAvatarPreviewSide, TGLightGramAvatarPreviewSide) uid:(int64_t)(index * 3 + 1) firstName:firstNames[index] lastName:lastNames[index] placeholder:nil];
    }];
}

- (void)refreshRoundness
{
    for (TGLetteredAvatarView *avatarView in _avatarViews)
        [avatarView setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect contentFrame = [self classicIOS6GroupedFrame];
    CGFloat spacing = MIN(28.0f, (contentFrame.size.width - TGLightGramAvatarPreviewSide * TGLightGramAvatarPreviewCount) / (TGLightGramAvatarPreviewCount + 1));
    CGFloat totalWidth = TGLightGramAvatarPreviewSide * TGLightGramAvatarPreviewCount + spacing * (TGLightGramAvatarPreviewCount - 1);
    CGFloat x = contentFrame.origin.x + CGFloor((contentFrame.size.width - totalWidth) / 2.0f);
    CGFloat y = CGFloor((self.bounds.size.height - TGLightGramAvatarPreviewSide) / 2.0f);
    for (TGLetteredAvatarView *avatarView in _avatarViews)
    {
        avatarView.frame = CGRectMake(x, y, TGLightGramAvatarPreviewSide, TGLightGramAvatarPreviewSide);
        x += TGLightGramAvatarPreviewSide + spacing;
    }
}

@end

@implementation TGLightGramAvatarPreviewCollectionItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.highlightable = false;
        self.selectable = false;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGLightGramAvatarPreviewCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 84.0f);
}

- (void)refresh
{
    [(TGLightGramAvatarPreviewCollectionItemView *)self.boundView refreshRoundness];
}

@end
