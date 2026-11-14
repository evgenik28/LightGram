#import "LGTheme.h"
#import "LGPalette.h"
#import "LGTypography.h"
#import "LGMetrics.h"
#import "LGAssets.h"
#import "LGSettingsAppearance.h"
#import "LGProfileAppearance.h"
#import "LGNavigationAppearance.h"
#import "LGTabBarAppearance.h"
#import "LGMusicPlayerScreenAppearance.h"
#import "LGDialogListAppearance.h"
#import "LGConversationAppearance.h"
#import "LGSearchBarAppearance.h"
#import "LGContactListAppearance.h"
#import "LGMusicPlayerAppearance.h"
#import "LGCommunitySheetAppearance.h"
#import "LGMenuSheetAppearance.h"
#import "LGSurfaceRenderer.h"
#import "../../LightGramPlatform/LGPlatformVersion.h"

static LGTheme *LGCurrentTheme = nil;
static BOOL LGBrandedThemeDark = NO;

@implementation LGTheme

+ (LGTheme *)themeForKind:(LGThemeKind)kind dark:(BOOL)dark
{
    LGTheme *theme = [[LGTheme alloc] init];
    theme.kind = kind;
    theme.dark = dark;

    LGPalette *palette = [[LGPalette alloc] init];
    palette.backgroundColor = [UIColor colorWithWhite:0.93f alpha:1.0f];
    palette.cardColor = [UIColor whiteColor];
    palette.primaryTextColor = [UIColor blackColor];
    palette.secondaryTextColor = [UIColor colorWithWhite:0.45f alpha:1.0f];
    palette.accentColor = [UIColor colorWithRed:0.16f green:0.47f blue:0.72f alpha:1.0f];
    palette.separatorColor = [UIColor colorWithWhite:0.44f alpha:0.28f];
    palette.selectionColor = [UIColor colorWithWhite:0.82f alpha:1.0f];
    palette.accessoryColor = [UIColor colorWithWhite:0.48f alpha:1.0f];
    palette.badgeTextColor = [UIColor whiteColor];
    palette.badgeColor = [UIColor colorWithRed:0.776f green:0.004f blue:0.004f alpha:1.0f];
    palette.badgeTopColor = [UIColor colorWithRed:0.776f green:0.004f blue:0.004f alpha:1.0f];
    palette.badgeBottomColor = [UIColor colorWithRed:0.404f green:0.035f blue:0.035f alpha:1.0f];
    palette.badgeBorderColor = [UIColor whiteColor];
    palette.badgeGlossColor = [UIColor colorWithWhite:1.0f alpha:0.32f];
    palette.badgeShadowColor = [UIColor colorWithWhite:0.0f alpha:0.42f];
    palette.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.2f];
    palette.presenceOnlineColor = [UIColor colorWithRed:0.20f green:0.72f blue:0.25f alpha:1.0f];
    palette.incomingBubbleColor = [UIColor whiteColor];
    palette.outgoingBubbleColor = [UIColor colorWithRed:0.82f green:0.93f blue:0.78f alpha:1.0f];
    palette.messageMetaColor = [UIColor colorWithWhite:0.42f alpha:1.0f];
    theme.palette = palette;

    LGTypography *typography = [[LGTypography alloc] init];
    typography.bodyFont = [UIFont systemFontOfSize:17.0f];
    typography.secondaryFont = [UIFont systemFontOfSize:15.0f];
    typography.settingsTitleFont = [UIFont boldSystemFontOfSize:18.0f];
    typography.dialogTitleFont = [UIFont boldSystemFontOfSize:16.0f];
    typography.dialogPreviewFont = [UIFont systemFontOfSize:14.0f];
    typography.dialogDateFont = [UIFont systemFontOfSize:12.0f];
    typography.messageFont = [UIFont systemFontOfSize:16.0f];
    typography.messageMetaFont = [UIFont systemFontOfSize:11.0f];
    typography.badgeFont = [UIFont boldSystemFontOfSize:12.0f];
    typography.navigationTitleFont = [UIFont boldSystemFontOfSize:20.0f];
    typography.sectionHeaderFont = [UIFont boldSystemFontOfSize:13.0f];
    theme.typography = typography;

    CGFloat scale = LGPlatformScreenScale();
    LGMetrics *metrics = [[LGMetrics alloc] init];
    metrics.pixel = 1.0f / MAX(1.0f, scale);
    metrics.navigationBarHeight = 44.0f;
    metrics.tabBarHeight = 49.0f;
    metrics.settingsRowHeight = 44.0f;
    metrics.settingsIconX = 17.0f;
    metrics.settingsIconSize = 16.0f;
    metrics.settingsTitleX = 43.0f;
    metrics.settingsTitleY = 7.0f;
    metrics.settingsTitleHeight = 22.0f;
    metrics.settingsAccessoryRight = 23.0f;
    metrics.settingsControlRight = 14.0f;
    metrics.settingsVerticalOffset = 1.0f;
    metrics.iconShadowOpacity = 0.10f;
    metrics.iconShadowRadius = 0.5f;
    metrics.iconShadowOffset = CGSizeMake(0.0f, 1.0f);
    metrics.badgeMinimumWidth = 18.0f;
    metrics.badgeHeight = 18.0f;
    metrics.badgeHorizontalPadding = 5.0f;
    metrics.badgeBorderWidth = MAX(metrics.pixel, 2.0f / MAX(1.0f, scale));
    metrics.badgeTextVerticalOffset = -1.0f;
    metrics.badgeShadowOffset = metrics.pixel;
    metrics.avatarSize = 40.0f;
    metrics.dialogRowHeight = 72.0f;
    metrics.dialogHorizontalInset = 8.0f;
    metrics.listHorizontalInset = 8.0f;
    metrics.listIconSpacing = 10.0f;
    metrics.listAccessorySpacing = 8.0f;
    metrics.separatorHeight = metrics.pixel;
    metrics.presenceDiameter = 10.0f;
    theme.metrics = metrics;

    LGAssets *assets = [[LGAssets alloc] init];
    theme.assets = assets;
    theme.surfaceRenderer = [[LGSurfaceRenderer alloc] initWithAssets:assets];

    theme.settingsAppearance = [LGSettingsAppearance brandedAppearanceDark:dark];
    theme.profileAppearance = [LGProfileAppearance brandedAppearanceDark:dark];
    theme.navigationAppearance = [LGNavigationAppearance brandedAppearanceDark:dark];
    theme.tabBarAppearance = [LGTabBarAppearance brandedAppearance];
    theme.dialogListAppearance = [LGDialogListAppearance brandedAppearanceDark:dark];
    theme.conversationAppearance = [LGConversationAppearance brandedAppearanceDark:dark];
    theme.searchBarAppearance = [LGSearchBarAppearance brandedAppearanceDark:dark];
    theme.contactListAppearance = [LGContactListAppearance brandedAppearanceDark:dark];
    theme.musicPlayerAppearance = [LGMusicPlayerAppearance brandedAppearanceDark:dark];
    theme.musicPlayerScreenAppearance = [LGMusicPlayerScreenAppearance brandedAppearance];
    theme.communitySheetAppearance = [LGCommunitySheetAppearance brandedAppearanceDark:dark navigationAppearance:theme.navigationAppearance];
    theme.menuSheetAppearance = [LGMenuSheetAppearance brandedAppearanceDark:dark];

    return theme;
}

+ (LGTheme *)brandedTheme
{
    BOOL dark = NO;
    @synchronized(self)
    {
        dark = LGBrandedThemeDark;
    }
    return [self brandedThemeDark:dark];
}

+ (LGTheme *)brandedThemeDark:(BOOL)dark
{
    static LGTheme *lightTheme = nil;
    static LGTheme *darkTheme = nil;
    @synchronized(self)
    {
        if (dark)
        {
            if (darkTheme == nil)
                darkTheme = [self themeForKind:LGThemeKindBranded dark:YES];
            return darkTheme;
        }
        if (lightTheme == nil)
            lightTheme = [self themeForKind:LGThemeKindBranded dark:NO];
        return lightTheme;
    }
}

+ (void)setBrandedThemeDark:(BOOL)dark
{
    @synchronized(self)
    {
        LGBrandedThemeDark = dark;
    }
}

+ (LGTheme *)currentTheme
{
    @synchronized(self)
    {
        if (LGCurrentTheme == nil)
            LGCurrentTheme = [self brandedTheme];
        return LGCurrentTheme;
    }
}

+ (void)setCurrentTheme:(LGTheme *)theme
{
    @synchronized(self)
    {
        LGCurrentTheme = theme == nil ? [self brandedTheme] : theme;
    }
}
@end
