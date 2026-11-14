/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGUserInfoButtonCollectionItem.h"

#import "TGUserInfoButtonCollectionItemView.h"

#import "TGPresentation.h"
#import "../LightGramUI/Core/LGTheme.h"
#import "../LightGramUI/Core/LGSettingsAppearance.h"
#import "../LightGramUI/Core/LGProfileAppearance.h"

@interface TGUserInfoButtonCollectionItem ()
{
    SEL _action;
    bool _hasCustomColor;
}

@end

@implementation TGUserInfoButtonCollectionItem

- (instancetype)initWithTitle:(NSString *)title action:(SEL)action
{
    self = [super init];
    if (self != nil)
    {
        self.transparent = true;
        
        _title = title;
        _action = action;
        _showsDisclosureIndicator = true;
        
        _titleColor = TGAccentColor();
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    if (!_hasCustomColor)
    {
        _titleColor = presentation.pallete.collectionMenuAccentColor;
        [(TGUserInfoButtonCollectionItemView *)self.boundView setTitleColor:_titleColor];
    }
}

- (void)setTitleColor:(UIColor *)titleColor
{
    _titleColor = titleColor;
    _hasCustomColor = true;
}

- (Class)itemViewClass
{
    return [TGUserInfoButtonCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 44.0f);
}

- (void)itemSelected:(id)actionTarget
{
    if (_action != NULL && [actionTarget respondsToSelector:_action])
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [actionTarget performSelector:_action];
#pragma clang diagnostic pop
    }
}

- (void)bindView:(TGUserInfoButtonCollectionItemView *)view
{
    [super bindView:view];
    
    [view setTitle:_title];
    [view setTitleColor:_titleColor];
    [view setIconName:_iconName];
    [view setEditing:_editing];
    [view setCenteredTitle:_centeredTitle];
    [view setShowsDisclosureIndicator:_showsDisclosureIndicator];
}

- (void)setTitle:(NSString *)title
{
    _title = title;
    
    [((TGUserInfoButtonCollectionItemView *)self.boundView) setTitle:_title];
}

- (void)setIconName:(NSString *)iconName
{
    _iconName = iconName;
    [(TGUserInfoButtonCollectionItemView *)[self boundView] setIconName:iconName];
}

- (void)setEditing:(bool)editing
{
    _editing = editing;
    
    [((TGUserInfoButtonCollectionItemView *)self.boundView) setEditing:_editing];
}

- (void)setCenteredTitle:(bool)centeredTitle
{
    _centeredTitle = centeredTitle;
    [((TGUserInfoButtonCollectionItemView *)self.boundView) setCenteredTitle:centeredTitle];
}

- (void)setShowsDisclosureIndicator:(bool)showsDisclosureIndicator
{
    _showsDisclosureIndicator = showsDisclosureIndicator;
    [((TGUserInfoButtonCollectionItemView *)self.boundView) setShowsDisclosureIndicator:showsDisclosureIndicator];
}

@end
