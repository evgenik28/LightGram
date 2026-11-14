#import "TGNavigationBarMusicPlayerProvider.h"

#import "TGMusicPlayerView.h"

#import "TGTelegraph.h"
#import "TGPresentation.h"

@implementation TGNavigationBarMusicPlayerProvider

- (CGFloat)musicPlayerHeight
{
    return false ? 44.0f : 37.0f;
}

- (UIView<TGNavigationBarMusicPlayerView> *)makeMusicPlayerView:(UINavigationController *)navigationController {
    return [[TGMusicPlayerView alloc] initWithNavigationController:navigationController];
}

- (SSignal *)musicPlayerIsActive {
    return [[[TGTelegraphInstance musicPlayer] playingStatus] map:^id(TGMusicPlayerStatus *status) {
        return @(status != nil);
    }];
}

@end
