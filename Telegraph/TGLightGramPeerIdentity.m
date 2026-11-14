#import "TGLightGramPeerIdentity.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGPeerIdAdapter.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGLightGramSettings.h"

@implementation TGLightGramCopyValueCollectionItem

- (void)itemSelected:(id)__unused actionTarget
{
    if (self.username.length == 0)
        return;
    [UIPasteboard generalPasteboard].string = self.username;
    [[[TGProgressWindow alloc] init] dismissWithSuccess];
}

@end

NSString *TGLightGramDisplayPeerId(int64_t peerId)
{
    return [[NSString alloc] initWithFormat:@"%lld", peerId];
}

NSArray *TGLightGramPeerIdentityItems(int64_t peerId, NSString *photoUrl)
{
    TGLightGramCopyValueCollectionItem *idItem = [[TGLightGramCopyValueCollectionItem alloc] initWithLabel:@"ID" username:TGLightGramDisplayPeerId(peerId)];
    idItem.deselectAutomatically = true;
    int32_t datacenterId = TGLightGramDatacenterForPhotoUrl(photoUrl);
    if (datacenterId == 0)
    {
        idItem.lastInList = true;
        return @[idItem];
    }
    TGLightGramCopyValueCollectionItem *dcItem = [[TGLightGramCopyValueCollectionItem alloc] initWithLabel:@"DC" username:[[NSString alloc] initWithFormat:@"%d", datacenterId]];
    dcItem.deselectAutomatically = true;
    dcItem.lastInList = true;
    return @[idItem, dcItem];
}
