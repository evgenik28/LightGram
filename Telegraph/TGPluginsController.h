#import "../LightGramRuntime/LGPluginAvailability.h"

#if LG_PLUGINS_AVAILABLE

#import "TGLightGramSettingsController.h"

@interface TGPluginsController : TGLightGramSettingsController

- (instancetype)init;

+ (bool)isPluginArchivePath:(NSString *)path fileName:(NSString *)fileName;
+ (void)presentInstallPromptForPath:(NSString *)path fileName:(NSString *)fileName;
+ (void)presentMenuItems:(NSArray *)items ofType:(NSString *)menuType context:(NSDictionary *)context fromController:(UIViewController *)controller;
+ (void)openPluginWithIdentifier:(NSString *)identifier;

@end

#endif
