#import "TGUserInfoUsernameCollectionItem.h"

@interface TGLightGramCopyValueCollectionItem : TGUserInfoUsernameCollectionItem
@end

#ifdef __cplusplus
extern "C" {
#endif

NSString *TGLightGramDisplayPeerId(int64_t peerId);
NSArray *TGLightGramPeerIdentityItems(int64_t peerId, NSString *photoUrl);

#ifdef __cplusplus
}
#endif
