#import "TGLightGramColorPreview.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentationPallete.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageUtils.h"
#import "../LightGramPlatform/LGPlatformText.h"

typedef enum {
    TGLightGramColorPreviewSceneSettings = 0,
    TGLightGramColorPreviewSceneTabs,
    TGLightGramColorPreviewSceneChatList,
    TGLightGramColorPreviewSceneChat
} TGLightGramColorPreviewScene;

@interface TGLightGramColorPreviewColors : NSObject

@property (nonatomic, strong) UIColor *screen, *list, *text, *secondary, *separator;
@property (nonatomic, strong) UIColor *bar, *barSeparator, *barTitle, *barButton;
@property (nonatomic, strong) UIColor *tabIcon, *tabText, *tabActive, *switchColor;
@property (nonatomic, strong) UIColor *dialogBackground, *dialogTitle, *dialogText, *dialogDate, *dialogBadge, *dialogBadgeText;
@property (nonatomic, strong) UIColor *chatBackground, *outgoingBubble, *outgoingText, *outgoingSecondary, *outgoingLink;
@property (nonatomic, strong) UIColor *incomingBubble, *incomingText, *incomingSecondary, *incomingLink;
@property (nonatomic, strong) UIColor *systemBackground, *systemText;
@property (nonatomic, strong) UIColor *inputPanel, *inputBorder, *inputField, *inputPlaceholder, *sendButton, *sendIcon;

@end

@implementation TGLightGramColorPreviewColors

@end

static TGLightGramColorPreviewScene TGLightGramColorPreviewSceneForPreview(TGPresentationColorPreview preview)
{
    switch (preview)
    {
        case TGPresentationColorPreviewTabIcons:
            return TGLightGramColorPreviewSceneTabs;
        case TGPresentationColorPreviewDialogTitle:
        case TGPresentationColorPreviewDialogText:
        case TGPresentationColorPreviewDialogDate:
        case TGPresentationColorPreviewDialogBadge:
        case TGPresentationColorPreviewDialogBadgeText:
            return TGLightGramColorPreviewSceneChatList;
        case TGPresentationColorPreviewOutgoingBubble:
        case TGPresentationColorPreviewOutgoingText:
        case TGPresentationColorPreviewOutgoingSecondary:
        case TGPresentationColorPreviewOutgoingLink:
        case TGPresentationColorPreviewIncomingBubble:
        case TGPresentationColorPreviewIncomingText:
        case TGPresentationColorPreviewIncomingSecondary:
        case TGPresentationColorPreviewIncomingLink:
        case TGPresentationColorPreviewSystemBackground:
        case TGPresentationColorPreviewSystemText:
        case TGPresentationColorPreviewInputPanel:
        case TGPresentationColorPreviewSendButton:
            return TGLightGramColorPreviewSceneChat;
        default:
            return TGLightGramColorPreviewSceneSettings;
    }
}

CGFloat TGLightGramColorPreviewHeight(TGPresentationColorPreview preview)
{
    switch (TGLightGramColorPreviewSceneForPreview(preview))
    {
        case TGLightGramColorPreviewSceneTabs:
            return 116.0f;
        case TGLightGramColorPreviewSceneChatList:
            return 128.0f;
        case TGLightGramColorPreviewSceneChat:
            return 204.0f;
        default:
            return 150.0f;
    }
}

static TGLightGramColorPreviewColors *TGLightGramColorPreviewResolveColors(TGPresentationColorPreview preview, TGPresentationPallete *pallete, UIColor *color)
{
    TGLightGramColorPreviewColors *colors = [[TGLightGramColorPreviewColors alloc] init];
    colors.screen = pallete.collectionMenuBackgroundColor;
    colors.list = pallete.collectionMenuCellBackgroundColor ?: pallete.backgroundColor;
    colors.text = pallete.collectionMenuTextColor;
    colors.secondary = pallete.collectionMenuVariantColor;
    colors.separator = pallete.collectionMenuSeparatorColor;
    colors.bar = pallete.barBackgroundColor;
    colors.barSeparator = pallete.barSeparatorColor;
    colors.barTitle = pallete.navigationTitleColor;
    colors.barButton = pallete.navigationButtonColor;
    colors.tabIcon = pallete.tabIconColor;
    colors.tabText = pallete.tabTextColor ?: pallete.tabIconColor;
    colors.tabActive = pallete.tabActiveIconColor;
    colors.switchColor = pallete.collectionMenuSwitchColor ?: pallete.accentColor;
    colors.dialogBackground = pallete.backgroundColor;
    colors.dialogTitle = pallete.dialogTitleColor;
    colors.dialogText = pallete.dialogTextColor;
    colors.dialogDate = pallete.dialogDateColor;
    colors.dialogBadge = pallete.dialogBadgeColor;
    colors.dialogBadgeText = pallete.dialogBadgeTextColor;
    colors.chatBackground = pallete.isDark ? UIColorRGB(0x18222d) : UIColorRGB(0xd6e4ef);
    colors.outgoingBubble = pallete.chatOutgoingBubbleColor;
    colors.outgoingText = pallete.chatOutgoingTextColor;
    colors.outgoingSecondary = pallete.chatOutgoingDateColor;
    colors.outgoingLink = pallete.chatOutgoingLinkColor;
    colors.incomingBubble = pallete.chatIncomingBubbleColor;
    colors.incomingText = pallete.chatIncomingTextColor;
    colors.incomingSecondary = pallete.chatIncomingDateColor;
    colors.incomingLink = pallete.chatIncomingLinkColor;
    colors.systemBackground = pallete.chatSystemBackgroundColor;
    colors.systemText = pallete.chatSystemTextColor;
    colors.inputPanel = pallete.chatInputBackgroundColor;
    colors.inputBorder = pallete.chatInputBorderColor ?: pallete.barSeparatorColor;
    colors.inputField = pallete.isDark ? UIColorRGB(0x2c2c2e) : [UIColor whiteColor];
    colors.inputPlaceholder = pallete.chatInputPlaceholderColor ?: pallete.secondaryTextColor;
    colors.sendButton = pallete.chatInputSendButtonColor;
    colors.sendIcon = pallete.chatInputSendButtonIconColor ?: [UIColor whiteColor];

    switch (preview)
    {
        case TGPresentationColorPreviewAccent:
            colors.barButton = color;
            colors.tabActive = color;
            colors.switchColor = color;
            colors.dialogBadge = color;
            colors.incomingLink = color;
            colors.sendButton = color;
            break;
        case TGPresentationColorPreviewScreenBackground:
            colors.screen = color;
            break;
        case TGPresentationColorPreviewListBackground:
            colors.list = color;
            colors.dialogBackground = color;
            break;
        case TGPresentationColorPreviewBar:
            colors.bar = color;
            break;
        case TGPresentationColorPreviewBarTitle:
            colors.barTitle = color;
            break;
        case TGPresentationColorPreviewTabIcons:
            colors.tabIcon = color;
            colors.tabText = color;
            break;
        case TGPresentationColorPreviewText:
            colors.text = color;
            break;
        case TGPresentationColorPreviewSecondaryText:
            colors.secondary = color;
            break;
        case TGPresentationColorPreviewSeparator:
            colors.separator = color;
            colors.barSeparator = color;
            break;
        case TGPresentationColorPreviewDialogTitle:
            colors.dialogTitle = color;
            break;
        case TGPresentationColorPreviewDialogText:
            colors.dialogText = color;
            break;
        case TGPresentationColorPreviewDialogDate:
            colors.dialogDate = color;
            break;
        case TGPresentationColorPreviewDialogBadge:
            colors.dialogBadge = color;
            break;
        case TGPresentationColorPreviewDialogBadgeText:
            colors.dialogBadgeText = color;
            break;
        case TGPresentationColorPreviewOutgoingBubble:
            colors.outgoingBubble = color;
            break;
        case TGPresentationColorPreviewOutgoingText:
            colors.outgoingText = color;
            break;
        case TGPresentationColorPreviewOutgoingSecondary:
            colors.outgoingSecondary = color;
            break;
        case TGPresentationColorPreviewOutgoingLink:
            colors.outgoingLink = color;
            break;
        case TGPresentationColorPreviewIncomingBubble:
            colors.incomingBubble = color;
            break;
        case TGPresentationColorPreviewIncomingText:
            colors.incomingText = color;
            break;
        case TGPresentationColorPreviewIncomingSecondary:
            colors.incomingSecondary = color;
            break;
        case TGPresentationColorPreviewIncomingLink:
            colors.incomingLink = color;
            break;
        case TGPresentationColorPreviewSystemBackground:
            colors.systemBackground = color;
            break;
        case TGPresentationColorPreviewSystemText:
            colors.systemText = color;
            break;
        case TGPresentationColorPreviewInputPanel:
            colors.inputPanel = color;
            break;
        case TGPresentationColorPreviewSendButton:
            colors.sendButton = color;
            break;
    }
    return colors;
}

static void TGLightGramColorPreviewAddRoundedRect(CGContextRef context, CGRect rect, CGFloat radius)
{
    radius = MIN(radius, MIN(rect.size.width, rect.size.height) / 2.0f);
    CGFloat minX = CGRectGetMinX(rect), midX = CGRectGetMidX(rect), maxX = CGRectGetMaxX(rect);
    CGFloat minY = CGRectGetMinY(rect), midY = CGRectGetMidY(rect), maxY = CGRectGetMaxY(rect);
    CGContextMoveToPoint(context, minX, midY);
    CGContextAddArcToPoint(context, minX, minY, midX, minY, radius);
    CGContextAddArcToPoint(context, maxX, minY, maxX, midY, radius);
    CGContextAddArcToPoint(context, maxX, maxY, midX, maxY, radius);
    CGContextAddArcToPoint(context, minX, maxY, minX, midY, radius);
    CGContextClosePath(context);
}

static void TGLightGramColorPreviewFillRect(CGContextRef context, CGRect rect, UIColor *color)
{
    if (color == nil)
        return;
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, rect);
}

static void TGLightGramColorPreviewFillRoundedRect(CGContextRef context, CGRect rect, CGFloat radius, UIColor *color)
{
    if (color == nil)
        return;
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextBeginPath(context);
    TGLightGramColorPreviewAddRoundedRect(context, rect, radius);
    CGContextFillPath(context);
}

static void TGLightGramColorPreviewFillCircle(CGContextRef context, CGPoint center, CGFloat radius, UIColor *color)
{
    if (color == nil)
        return;
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(center.x - radius, center.y - radius, radius * 2.0f, radius * 2.0f));
}

static void TGLightGramColorPreviewHairline(CGContextRef context, CGFloat x, CGFloat y, CGFloat width, UIColor *color)
{
    TGLightGramColorPreviewFillRect(context, CGRectMake(x, y, width, TGScreenPixel), color);
}

static void TGLightGramColorPreviewStrokeLines(CGContextRef context, const CGPoint *points, size_t count, CGFloat width, UIColor *color)
{
    if (color == nil)
        return;
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, width);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextBeginPath(context);
    CGContextAddLines(context, points, count);
    CGContextStrokePath(context);
}

static CGFloat TGLightGramColorPreviewTextWidth(NSString *text, UIFont *font)
{
    return text.length == 0 ? 0.0f : CGCeil([text sizeWithFont:font].width);
}

static void TGLightGramColorPreviewDrawText(NSString *text, CGFloat x, CGFloat centerY, CGFloat width, UIFont *font, UIColor *color, NSTextAlignment alignment)
{
    if (text.length == 0 || color == nil || width < 1.0f)
        return;
    CGFloat lineHeight = CGCeil(LGPlatformFontLineHeight(font));
    [color set];
    [text drawInRect:CGRectMake(x, CGFloor(centerY - lineHeight / 2.0f), width, lineHeight) withFont:font lineBreakMode:NSLineBreakByTruncatingTail alignment:alignment];
}

static void TGLightGramColorPreviewDrawSwitch(CGContextRef context, CGRect track, UIColor *color)
{
    TGLightGramColorPreviewFillRoundedRect(context, track, track.size.height / 2.0f, color);
    CGFloat knobRadius = track.size.height / 2.0f - 2.0f;
    CGPoint knobCenter = CGPointMake(CGRectGetMaxX(track) - 2.0f - knobRadius, CGRectGetMidY(track));
    TGLightGramColorPreviewFillCircle(context, knobCenter, knobRadius + 0.5f, [UIColor colorWithWhite:0.0f alpha:0.12f]);
    TGLightGramColorPreviewFillCircle(context, knobCenter, knobRadius, [UIColor whiteColor]);
}

static void TGLightGramColorPreviewDrawDisclosure(CGContextRef context, CGFloat rightX, CGFloat centerY, UIColor *color)
{
    CGPoint points[] = {CGPointMake(rightX - 5.0f, centerY - 5.0f), CGPointMake(rightX, centerY), CGPointMake(rightX - 5.0f, centerY + 5.0f)};
    TGLightGramColorPreviewStrokeLines(context, points, 3, 2.0f, color);
}

static void TGLightGramColorPreviewDrawSettingsScene(CGContextRef context, CGSize size, TGLightGramColorPreviewColors *colors)
{
    CGFloat barHeight = 40.0f;
    TGLightGramColorPreviewFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height), colors.screen);
    TGLightGramColorPreviewFillRect(context, CGRectMake(0.0f, 0.0f, size.width, barHeight), colors.bar);
    TGLightGramColorPreviewHairline(context, 0.0f, barHeight - TGScreenPixel, size.width, colors.barSeparator);

    CGPoint chevron[] = {CGPointMake(16.0f, barHeight / 2.0f - 7.0f), CGPointMake(10.0f, barHeight / 2.0f), CGPointMake(16.0f, barHeight / 2.0f + 7.0f)};
    TGLightGramColorPreviewStrokeLines(context, chevron, 3, 2.5f, colors.barButton);
    UIFont *buttonFont = TGSystemFontOfSize(15.0f);
    NSString *backTitle = TGLocalized(@"Common.Back");
    CGFloat backWidth = MIN(TGLightGramColorPreviewTextWidth(backTitle, buttonFont), size.width * 0.28f);
    TGLightGramColorPreviewDrawText(backTitle, 21.0f, barHeight / 2.0f, backWidth, buttonFont, colors.barButton, NSTextAlignmentLeft);
    CGFloat titleInset = 21.0f + backWidth + 8.0f;
    TGLightGramColorPreviewDrawText(TGLocalized(@"Appearance.Title"), titleInset, barHeight / 2.0f, size.width - titleInset * 2.0f, TGMediumSystemFontOfSize(16.0f), colors.barTitle, NSTextAlignmentCenter);

    TGLightGramColorPreviewDrawText([TGLocalized(@"LightGramColors.SectionGeneral") uppercaseString], 14.0f, barHeight + 18.0f, size.width - 28.0f, TGSystemFontOfSize(12.0f), colors.secondary, NSTextAlignmentLeft);

    CGFloat rowHeight = 38.0f;
    CGFloat groupY = barHeight + 30.0f;
    TGLightGramColorPreviewFillRect(context, CGRectMake(0.0f, groupY, size.width, rowHeight * 2.0f), colors.list);
    TGLightGramColorPreviewHairline(context, 0.0f, groupY, size.width, colors.separator);
    TGLightGramColorPreviewHairline(context, 14.0f, groupY + rowHeight, size.width - 14.0f, colors.separator);
    TGLightGramColorPreviewHairline(context, 0.0f, groupY + rowHeight * 2.0f - TGScreenPixel, size.width, colors.separator);

    UIFont *rowFont = TGSystemFontOfSize(15.0f);
    CGRect track = CGRectMake(size.width - 14.0f - 42.0f, groupY + (rowHeight - 24.0f) / 2.0f, 42.0f, 24.0f);
    TGLightGramColorPreviewDrawText(TGLocalized(@"Settings.NotificationsAndSounds"), 14.0f, groupY + rowHeight / 2.0f, CGRectGetMinX(track) - 22.0f, rowFont, colors.text, NSTextAlignmentLeft);
    TGLightGramColorPreviewDrawSwitch(context, track, colors.switchColor);

    CGFloat secondCenter = groupY + rowHeight * 1.5f;
    NSString *value = TGLocalized(@"LightGramColors.PreviewValue");
    CGFloat valueWidth = TGLightGramColorPreviewTextWidth(value, rowFont);
    CGFloat valueX = size.width - 14.0f - 12.0f - valueWidth;
    TGLightGramColorPreviewDrawDisclosure(context, size.width - 14.0f, secondCenter, colors.secondary);
    TGLightGramColorPreviewDrawText(value, valueX, secondCenter, valueWidth, rowFont, colors.secondary, NSTextAlignmentRight);
    TGLightGramColorPreviewDrawText(TGLocalized(@"Settings.PrivacySettings"), 14.0f, secondCenter, valueX - 22.0f, rowFont, colors.text, NSTextAlignmentLeft);
}

static void TGLightGramColorPreviewDrawTabIcon(CGContextRef context, NSUInteger index, CGPoint center, UIColor *color)
{
    switch (index)
    {
        case 0:
            TGLightGramColorPreviewFillCircle(context, CGPointMake(center.x, center.y - 4.0f), 4.5f, color);
            TGLightGramColorPreviewFillRoundedRect(context, CGRectMake(center.x - 8.0f, center.y + 2.0f, 16.0f, 8.0f), 4.0f, color);
            break;
        case 1:
        {
            CGContextSetStrokeColorWithColor(context, color.CGColor);
            CGContextSetLineWidth(context, 2.0f);
            CGContextBeginPath(context);
            TGLightGramColorPreviewAddRoundedRect(context, CGRectMake(center.x - 5.5f, center.y - 9.0f, 11.0f, 18.0f), 2.5f);
            CGContextStrokePath(context);
            TGLightGramColorPreviewFillRect(context, CGRectMake(center.x - 2.0f, center.y + 5.0f, 4.0f, 1.5f), color);
            break;
        }
        case 2:
        {
            TGLightGramColorPreviewFillRoundedRect(context, CGRectMake(center.x - 10.0f, center.y - 8.0f, 20.0f, 14.0f), 6.0f, color);
            CGContextSetFillColorWithColor(context, color.CGColor);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, center.x - 6.0f, center.y + 4.0f);
            CGContextAddLineToPoint(context, center.x - 9.0f, center.y + 10.0f);
            CGContextAddLineToPoint(context, center.x - 1.0f, center.y + 5.0f);
            CGContextClosePath(context);
            CGContextFillPath(context);
            break;
        }
        default:
            CGContextSetStrokeColorWithColor(context, color.CGColor);
            CGContextSetLineWidth(context, 3.0f);
            CGContextStrokeEllipseInRect(context, CGRectMake(center.x - 7.5f, center.y - 7.5f, 15.0f, 15.0f));
            TGLightGramColorPreviewFillCircle(context, center, 2.5f, color);
            break;
    }
}

static void TGLightGramColorPreviewDrawTabsScene(CGContextRef context, CGSize size, TGLightGramColorPreviewColors *colors)
{
    TGLightGramColorPreviewFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height), colors.screen);
    CGFloat rowHeight = 38.0f;
    CGFloat rowY = 12.0f;
    TGLightGramColorPreviewFillRect(context, CGRectMake(0.0f, rowY, size.width, rowHeight), colors.list);
    TGLightGramColorPreviewHairline(context, 0.0f, rowY, size.width, colors.separator);
    TGLightGramColorPreviewHairline(context, 0.0f, rowY + rowHeight - TGScreenPixel, size.width, colors.separator);
    TGLightGramColorPreviewDrawText(TGLocalized(@"Settings.NotificationsAndSounds"), 14.0f, rowY + rowHeight / 2.0f, size.width - 40.0f, TGSystemFontOfSize(15.0f), colors.text, NSTextAlignmentLeft);
    TGLightGramColorPreviewDrawDisclosure(context, size.width - 14.0f, rowY + rowHeight / 2.0f, colors.secondary);

    CGFloat tabHeight = 54.0f;
    CGFloat tabY = size.height - tabHeight;
    TGLightGramColorPreviewFillRect(context, CGRectMake(0.0f, tabY, size.width, tabHeight), colors.bar);
    TGLightGramColorPreviewHairline(context, 0.0f, tabY, size.width, colors.barSeparator);

    NSArray *titles = @[TGLocalized(@"Contacts.TabTitle"), TGLocalized(@"Calls.TabTitle"), TGLocalized(@"DialogList.TabTitle"), TGLocalized(@"Settings.TabTitle")];
    NSUInteger activeIndex = 2;
    CGFloat itemWidth = size.width / (CGFloat)titles.count;
    UIFont *font = TGSystemFontOfSize(10.0f);
    for (NSUInteger i = 0; i < titles.count; i++)
    {
        CGFloat centerX = itemWidth * ((CGFloat)i + 0.5f);
        bool active = i == activeIndex;
        TGLightGramColorPreviewDrawTabIcon(context, i, CGPointMake(centerX, tabY + 21.0f), active ? colors.tabActive : colors.tabIcon);
        TGLightGramColorPreviewDrawText(titles[i], itemWidth * (CGFloat)i + 2.0f, tabY + 43.0f, itemWidth - 4.0f, font, active ? colors.tabActive : colors.tabText, NSTextAlignmentCenter);
    }
}

static void TGLightGramColorPreviewDrawDialogRow(CGContextRef context, CGSize size, CGFloat rowY, CGFloat rowHeight, NSString *name, NSString *text, NSString *time, NSString *badge, UIColor *avatarColor, TGLightGramColorPreviewColors *colors)
{
    CGFloat avatarRadius = 22.0f;
    CGPoint avatarCenter = CGPointMake(10.0f + avatarRadius, rowY + rowHeight / 2.0f);
    TGLightGramColorPreviewFillCircle(context, avatarCenter, avatarRadius, avatarColor);
    NSString *initial = name.length != 0 ? [[name substringToIndex:1] uppercaseString] : @"";
    TGLightGramColorPreviewDrawText(initial, avatarCenter.x - avatarRadius, avatarCenter.y, avatarRadius * 2.0f, TGMediumSystemFontOfSize(18.0f), [UIColor whiteColor], NSTextAlignmentCenter);

    CGFloat textX = avatarCenter.x + avatarRadius + 10.0f;
    CGFloat rightX = size.width - 10.0f;
    UIFont *timeFont = TGSystemFontOfSize(13.0f);
    CGFloat timeWidth = TGLightGramColorPreviewTextWidth(time, timeFont);
    CGFloat titleCenter = rowY + 20.0f;
    TGLightGramColorPreviewDrawText(time, rightX - timeWidth, titleCenter, timeWidth, timeFont, colors.dialogDate, NSTextAlignmentRight);
    TGLightGramColorPreviewDrawText(name, textX, titleCenter, rightX - timeWidth - 8.0f - textX, TGMediumSystemFontOfSize(16.0f), colors.dialogTitle, NSTextAlignmentLeft);

    CGFloat textCenter = rowY + 43.0f;
    CGFloat textRight = rightX;
    if (badge.length != 0)
    {
        UIFont *badgeFont = TGMediumSystemFontOfSize(13.0f);
        CGFloat badgeWidth = MAX(20.0f, TGLightGramColorPreviewTextWidth(badge, badgeFont) + 12.0f);
        CGRect badgeRect = CGRectMake(rightX - badgeWidth, textCenter - 10.0f, badgeWidth, 20.0f);
        TGLightGramColorPreviewFillRoundedRect(context, badgeRect, 10.0f, colors.dialogBadge);
        TGLightGramColorPreviewDrawText(badge, badgeRect.origin.x, textCenter, badgeWidth, badgeFont, colors.dialogBadgeText, NSTextAlignmentCenter);
        textRight = badgeRect.origin.x - 8.0f;
    }
    TGLightGramColorPreviewDrawText(text, textX, textCenter, textRight - textX, TGSystemFontOfSize(15.0f), colors.dialogText, NSTextAlignmentLeft);
}

static void TGLightGramColorPreviewDrawChatListScene(CGContextRef context, CGSize size, TGLightGramColorPreviewColors *colors)
{
    TGLightGramColorPreviewFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height), colors.dialogBackground);
    CGFloat rowHeight = size.height / 2.0f;
    TGLightGramColorPreviewDrawDialogRow(context, size, 0.0f, rowHeight, TGLocalized(@"Appearance.PreviewReplyAuthor"), TGLocalized(@"Appearance.PreviewIncomingText"), @"18:21", @"3", UIColorRGB(0x5cafe9), colors);
    TGLightGramColorPreviewHairline(context, 64.0f, rowHeight, size.width - 64.0f, colors.separator);
    TGLightGramColorPreviewDrawDialogRow(context, size, rowHeight, rowHeight, @"LightGram", TGLocalized(@"Appearance.PreviewOutgoingText"), @"17:05", nil, UIColorRGB(0x6fcf75), colors);
}

static void TGLightGramColorPreviewDrawBubble(CGContextRef context, CGSize size, CGFloat y, bool outgoing, NSString *text, NSString *link, NSString *time, UIColor *bubbleColor, UIColor *textColor, UIColor *linkColor, UIColor *secondaryColor)
{
    UIFont *textFont = TGSystemFontOfSize(15.0f);
    UIFont *timeFont = TGSystemFontOfSize(11.0f);
    CGFloat padding = 10.0f;
    CGFloat checksWidth = outgoing ? 14.0f : 0.0f;
    CGFloat timeWidth = TGLightGramColorPreviewTextWidth(time, timeFont) + checksWidth;
    CGFloat maxContentWidth = size.width * 0.74f - padding * 2.0f;
    CGFloat textWidth = MIN(maxContentWidth, TGLightGramColorPreviewTextWidth(text, textFont));
    CGFloat linkWidth = MIN(maxContentWidth - timeWidth - 8.0f, TGLightGramColorPreviewTextWidth(link, textFont));
    CGFloat contentWidth = MAX(textWidth, linkWidth + 8.0f + timeWidth);
    CGFloat lineHeight = 19.0f;
    CGRect bubble = CGRectMake(0.0f, y, contentWidth + padding * 2.0f, lineHeight * 2.0f + 12.0f);
    bubble.origin.x = outgoing ? size.width - 8.0f - bubble.size.width : 8.0f;
    TGLightGramColorPreviewFillRoundedRect(context, bubble, 15.0f, bubbleColor);

    CGFloat contentX = bubble.origin.x + padding;
    CGFloat firstCenter = y + 6.0f + lineHeight / 2.0f;
    CGFloat secondCenter = firstCenter + lineHeight;
    TGLightGramColorPreviewDrawText(text, contentX, firstCenter, textWidth, textFont, textColor, NSTextAlignmentLeft);
    TGLightGramColorPreviewDrawText(link, contentX, secondCenter, linkWidth, textFont, linkColor, NSTextAlignmentLeft);

    CGFloat timeX = CGRectGetMaxX(bubble) - padding - timeWidth;
    CGFloat timeCenter = secondCenter + 2.0f;
    TGLightGramColorPreviewDrawText(time, timeX, timeCenter, timeWidth - checksWidth, timeFont, secondaryColor, NSTextAlignmentLeft);
    if (outgoing)
    {
        CGFloat checkX = CGRectGetMaxX(bubble) - padding - 12.0f;
        for (NSUInteger i = 0; i < 2; i++)
        {
            CGFloat offset = (CGFloat)i * 4.0f;
            CGPoint points[] = {CGPointMake(checkX + offset, timeCenter), CGPointMake(checkX + offset + 2.5f, timeCenter + 2.5f), CGPointMake(checkX + offset + 7.0f, timeCenter - 3.0f)};
            TGLightGramColorPreviewStrokeLines(context, points, 3, 1.4f, secondaryColor);
        }
    }
}

static void TGLightGramColorPreviewDrawChatScene(CGContextRef context, CGSize size, TGLightGramColorPreviewColors *colors)
{
    TGLightGramColorPreviewFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height), colors.chatBackground);

    UIFont *systemFont = TGMediumSystemFontOfSize(13.0f);
    NSString *day = TGLocalized(@"Weekday.Today");
    CGFloat pillWidth = TGLightGramColorPreviewTextWidth(day, systemFont) + 18.0f;
    CGRect pill = CGRectMake(CGFloor((size.width - pillWidth) / 2.0f), 8.0f, pillWidth, 22.0f);
    TGLightGramColorPreviewFillRoundedRect(context, pill, 11.0f, colors.systemBackground);
    TGLightGramColorPreviewDrawText(day, pill.origin.x, CGRectGetMidY(pill), pill.size.width, systemFont, colors.systemText, NSTextAlignmentCenter);

    TGLightGramColorPreviewDrawBubble(context, size, 38.0f, false, TGLocalized(@"Appearance.PreviewIncomingText"), @"telegram.org", @"18:20", colors.incomingBubble, colors.incomingText, colors.incomingLink, colors.incomingSecondary);
    TGLightGramColorPreviewDrawBubble(context, size, 96.0f, true, TGLocalized(@"Appearance.PreviewOutgoingText"), @"t.me/lightgram", @"18:21", colors.outgoingBubble, colors.outgoingText, colors.outgoingLink, colors.outgoingSecondary);

    CGFloat panelHeight = 46.0f;
    CGFloat panelY = size.height - panelHeight;
    TGLightGramColorPreviewFillRect(context, CGRectMake(0.0f, panelY, size.width, panelHeight), colors.inputPanel);
    TGLightGramColorPreviewHairline(context, 0.0f, panelY, size.width, colors.inputBorder);
    CGFloat buttonRadius = 15.0f;
    CGPoint buttonCenter = CGPointMake(size.width - 8.0f - buttonRadius, panelY + panelHeight / 2.0f);
    CGRect field = CGRectMake(8.0f, buttonCenter.y - buttonRadius, buttonCenter.x - buttonRadius - 16.0f, buttonRadius * 2.0f);
    TGLightGramColorPreviewFillRoundedRect(context, field, buttonRadius, colors.inputField);
    TGLightGramColorPreviewDrawText(TGLocalized(@"Conversation.InputTextPlaceholder"), field.origin.x + 12.0f, CGRectGetMidY(field), field.size.width - 24.0f, TGSystemFontOfSize(15.0f), colors.inputPlaceholder, NSTextAlignmentLeft);
    TGLightGramColorPreviewFillCircle(context, buttonCenter, buttonRadius, colors.sendButton);
    CGPoint arrowStem[] = {CGPointMake(buttonCenter.x, buttonCenter.y + 6.0f), CGPointMake(buttonCenter.x, buttonCenter.y - 6.0f)};
    CGPoint arrowHead[] = {CGPointMake(buttonCenter.x - 5.0f, buttonCenter.y - 1.0f), CGPointMake(buttonCenter.x, buttonCenter.y - 6.0f), CGPointMake(buttonCenter.x + 5.0f, buttonCenter.y - 1.0f)};
    TGLightGramColorPreviewStrokeLines(context, arrowStem, 2, 2.2f, colors.sendIcon);
    TGLightGramColorPreviewStrokeLines(context, arrowHead, 3, 2.2f, colors.sendIcon);
}

UIImage *TGLightGramColorPreviewImage(TGPresentationColorPreview preview, TGPresentationPallete *pallete, UIColor *color, CGSize size)
{
    if (size.width < 1.0f || size.height < 1.0f || pallete == nil || color == nil)
        return nil;

    TGLightGramColorPreviewColors *colors = TGLightGramColorPreviewResolveColors(preview, pallete, color);

    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect bounds = CGRectMake(0.0f, 0.0f, size.width, size.height);
    CGFloat cornerRadius = 10.0f;

    CGContextSaveGState(context);
    CGContextBeginPath(context);
    TGLightGramColorPreviewAddRoundedRect(context, bounds, cornerRadius);
    CGContextClip(context);
    switch (TGLightGramColorPreviewSceneForPreview(preview))
    {
        case TGLightGramColorPreviewSceneTabs:
            TGLightGramColorPreviewDrawTabsScene(context, size, colors);
            break;
        case TGLightGramColorPreviewSceneChatList:
            TGLightGramColorPreviewDrawChatListScene(context, size, colors);
            break;
        case TGLightGramColorPreviewSceneChat:
            TGLightGramColorPreviewDrawChatScene(context, size, colors);
            break;
        default:
            TGLightGramColorPreviewDrawSettingsScene(context, size, colors);
            break;
    }
    CGContextRestoreGState(context);

    UIColor *borderColor = pallete.collectionMenuSeparatorColor;
    if (borderColor != nil)
    {
        CGFloat inset = TGScreenPixel / 2.0f;
        CGContextSetStrokeColorWithColor(context, borderColor.CGColor);
        CGContextSetLineWidth(context, TGScreenPixel);
        CGContextBeginPath(context);
        TGLightGramColorPreviewAddRoundedRect(context, CGRectInset(bounds, inset, inset), cornerRadius);
        CGContextStrokePath(context);
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

UIImage *TGLightGramColorSwatchImage(UIColor *color, CGFloat diameter, UIColor *borderColor)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect rect = CGRectMake(0.0f, 0.0f, diameter, diameter);
    if (color != nil)
    {
        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextFillEllipseInRect(context, CGRectInset(rect, 1.0f, 1.0f));
    }
    if (borderColor != nil)
    {
        CGContextSetStrokeColorWithColor(context, borderColor.CGColor);
        CGContextSetLineWidth(context, 1.0f);
        CGContextStrokeEllipseInRect(context, CGRectInset(rect, 1.0f, 1.0f));
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

void TGLightGramColorGetHSB(UIColor *color, CGFloat *hue, CGFloat *saturation, CGFloat *brightness)
{
    CGFloat h = 0.0f, s = 0.0f, v = 0.0f;
    if (color != nil)
    {
        const CGFloat *components = CGColorGetComponents(color.CGColor);
        size_t count = CGColorGetNumberOfComponents(color.CGColor);
        CGFloat red = components[0];
        CGFloat green = count >= 3 ? components[1] : red;
        CGFloat blue = count >= 3 ? components[2] : red;
        CGFloat maxValue = MAX(red, MAX(green, blue));
        CGFloat minValue = MIN(red, MIN(green, blue));
        CGFloat delta = maxValue - minValue;
        v = maxValue;
        s = maxValue > FLT_EPSILON ? delta / maxValue : 0.0f;
        if (delta > FLT_EPSILON)
        {
            if (maxValue == red)
                h = (green - blue) / delta + (green < blue ? 6.0f : 0.0f);
            else if (maxValue == green)
                h = (blue - red) / delta + 2.0f;
            else
                h = (red - green) / delta + 4.0f;
            h /= 6.0f;
        }
    }
    if (hue != NULL)
        *hue = h;
    if (saturation != NULL)
        *saturation = s;
    if (brightness != NULL)
        *brightness = v;
}

NSString *TGLightGramColorHexString(UIColor *color)
{
    return [[NSString alloc] initWithFormat:@"#%06X", (unsigned int)(TGColorHexCode(color) & 0xffffff)];
}
