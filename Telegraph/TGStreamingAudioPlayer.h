#import "TGAudioPlayer.h"

#import <AudioToolbox/AudioToolbox.h>

@class LGMediaStreamReader;

@interface TGStreamingAudioPlayer : TGAudioPlayer

+ (AudioFileTypeID)fileTypeForPathExtension:(NSString *)pathExtension;

- (instancetype)initWithReader:(LGMediaStreamReader *)reader fileType:(AudioFileTypeID)fileType music:(bool)music controlAudioSession:(bool)controlAudioSession;

@end
