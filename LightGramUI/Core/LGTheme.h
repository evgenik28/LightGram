#import <Foundation/Foundation.h>

@class LGPalette;
@class LGTypography;
@class LGMetrics;
@class LGAssets;
@class LGSettingsAppearance;
@class LGProfileAppearance;
@class LGNavigationAppearance;
@class LGTabBarAppearance;
@class LGDialogListAppearance;
@class LGConversationAppearance;
@class LGSearchBarAppearance;
@class LGContactListAppearance;
@class LGMusicPlayerAppearance;
@class LGMusicPlayerScreenAppearance;
@class LGCommunitySheetAppearance;
@class LGMenuSheetAppearance;
@class LGSurfaceRenderer;

typedef enum {
    LGThemeKindBranded = 0
} LGThemeKind;

@interface LGTheme : NSObject
@property (nonatomic) LGThemeKind kind;
@property (nonatomic) BOOL dark;
@property (nonatomic, retain) LGPalette *palette;
@property (nonatomic, retain) LGTypography *typography;
@property (nonatomic, retain) LGMetrics *metrics;
@property (nonatomic, retain) LGAssets *assets;
@property (nonatomic, retain) LGSettingsAppearance *settingsAppearance;
@property (nonatomic, retain) LGProfileAppearance *profileAppearance;
@property (nonatomic, retain) LGNavigationAppearance *navigationAppearance;
@property (nonatomic, retain) LGTabBarAppearance *tabBarAppearance;
@property (nonatomic, retain) LGDialogListAppearance *dialogListAppearance;
@property (nonatomic, retain) LGConversationAppearance *conversationAppearance;
@property (nonatomic, retain) LGSearchBarAppearance *searchBarAppearance;
@property (nonatomic, retain) LGContactListAppearance *contactListAppearance;
@property (nonatomic, retain) LGMusicPlayerAppearance *musicPlayerAppearance;
@property (nonatomic, retain) LGMusicPlayerScreenAppearance *musicPlayerScreenAppearance;
@property (nonatomic, retain) LGCommunitySheetAppearance *communitySheetAppearance;
@property (nonatomic, retain) LGMenuSheetAppearance *menuSheetAppearance;
@property (nonatomic, retain) LGSurfaceRenderer *surfaceRenderer;
+ (LGTheme *)brandedTheme;
+ (LGTheme *)brandedThemeDark:(BOOL)dark;
+ (void)setBrandedThemeDark:(BOOL)dark;
+ (LGTheme *)currentTheme;
+ (void)setCurrentTheme:(LGTheme *)theme;
@end
