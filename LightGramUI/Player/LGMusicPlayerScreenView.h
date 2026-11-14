#import <UIKit/UIKit.h>

@class LGTheme;

typedef enum {
    LGMusicPlayerScreenOrderNormal = 0,
    LGMusicPlayerScreenOrderReversed = 1,
    LGMusicPlayerScreenOrderShuffled = 2
} LGMusicPlayerScreenOrder;

typedef enum {
    LGMusicPlayerScreenRepeatNone = 0,
    LGMusicPlayerScreenRepeatAll = 1,
    LGMusicPlayerScreenRepeatOne = 2
} LGMusicPlayerScreenRepeat;

@interface LGMusicPlayerScreenRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *durationText;
@end

@interface LGMusicPlayerScreenView : UIView

@property (nonatomic) UIEdgeInsets contentInsets;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *backTitle;
@property (nonatomic, copy) NSString *trackTitle;
@property (nonatomic, copy) NSString *trackSubtitle;
@property (nonatomic, copy) NSArray *rows;
@property (nonatomic) bool paused;
@property (nonatomic) bool controlsEnabled;
@property (nonatomic) LGMusicPlayerScreenOrder order;
@property (nonatomic) LGMusicPlayerScreenRepeat repeat;
@property (nonatomic, readonly) UIView *displayView;
@property (nonatomic, readonly) bool scrubbing;
@property (nonatomic, strong) UIView *progressAccessoryView;

@property (nonatomic, copy) void (^backPressed)(void);
@property (nonatomic, copy) void (^playPausePressed)(void);
@property (nonatomic, copy) void (^previousPressed)(void);
@property (nonatomic, copy) void (^nextPressed)(void);
@property (nonatomic, copy) void (^orderPressed)(void);
@property (nonatomic, copy) void (^repeatPressed)(void);
@property (nonatomic, copy) void (^rowSelected)(NSUInteger index);
@property (nonatomic, copy) void (^actionsRequested)(void);
@property (nonatomic, copy) void (^scrubbingBegan)(void);
@property (nonatomic, copy) void (^scrubbingFinished)(CGFloat progress);
@property (nonatomic, copy) void (^scrubbingCancelled)(void);

- (instancetype)initWithFrame:(CGRect)frame theme:(LGTheme *)theme;
- (void)setProgress:(CGFloat)progress knobVisible:(bool)knobVisible;
- (void)scrollToRowAtIndex:(NSUInteger)index animated:(bool)animated;

@end
