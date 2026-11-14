#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

FOUNDATION_EXPORT BOOL LGPlatformMediaDownloadsRequireUserAction(void);
FOUNDATION_EXPORT BOOL LGPlatformCameraAvailable(void);
FOUNDATION_EXPORT BOOL LGPlatformVideoPlaybackAvailable(void);
FOUNDATION_EXPORT BOOL LGPlatformAVPlayerAvailable(void);
FOUNDATION_EXPORT BOOL LGPlatformHEVCHardwareDecodeAvailable(void);
FOUNDATION_EXPORT BOOL LGPlatformAVCaptureAvailable(void);
FOUNDATION_EXPORT BOOL LGPlatformCoreImageAvailable(void);
FOUNDATION_EXPORT BOOL LGPlatformCaptureConnectionIsVideoMirrored(id connection);
FOUNDATION_EXPORT void LGPlatformSetCaptureConnectionVideoMirrored(id connection, BOOL mirrored);
FOUNDATION_EXPORT void LGPlatformConfigureVolumeView(UIView *volumeView, UIImage *minimumTrackImage, UIImage *maximumTrackImage, UIImage *thumbImage, BOOL showsRouteButton);

FOUNDATION_EXPORT UIImage *LGPlatformVideoThumbnailAtURL(NSURL *url, NSTimeInterval time, CGSize maximumSize);
FOUNDATION_EXPORT BOOL LGPlatformReadVideoMetadataAtURL(NSURL *url, NSTimeInterval *duration, CGSize *dimensions);

@interface LGPlatformMoviePlayer : NSObject

@property (nonatomic, readonly) UIView *view;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval currentTime;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic, readonly) BOOL supportsInlinePlayback;
@property (nonatomic, readonly) BOOL supportsSeeking;
@property (nonatomic, copy) void (^playbackFinished)(void);

- (instancetype)initWithURL:(NSURL *)url;
- (void)play;
- (void)pause;
- (void)stop;
- (BOOL)seekToTime:(NSTimeInterval)time;

@end
