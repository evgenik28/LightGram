#import "TGLightGramSettingsController.h"

@interface TGLightGramRootSettingsController : TGLightGramSettingsController
@end

@interface TGLightGramGeneralSettingsController : TGLightGramSettingsController
@end

@interface TGLightGramMessagesSettingsController : TGLightGramSettingsController
@end

#ifdef __cplusplus
extern "C" {
#endif

NSArray *TGLightGramDoubleTapActions(bool outgoing);
NSArray *TGLightGramMenuActionIdentifiers(void);

#ifdef __cplusplus
}
#endif
