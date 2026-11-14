#import <UIKit/UIKit.h>

@class LGSurfaceStyle;

typedef enum {
    LGMusicPlayerGlyphPlay,
    LGMusicPlayerGlyphPause,
    LGMusicPlayerGlyphClose,
    LGMusicPlayerGlyphMusic,
    LGMusicPlayerGlyphChevron
} LGMusicPlayerGlyph;

@interface LGMusicPlayerAppearance : NSObject
@property (nonatomic, retain) LGSurfaceStyle *backgroundSurfaceStyle;
@property (nonatomic, retain) LGSurfaceStyle *displaySurfaceStyle;
@property (nonatomic, retain) UIFont *font;
@property (nonatomic, retain) UIColor *titleColor;
@property (nonatomic, retain) UIColor *timeColor;
@property (nonatomic, retain) UIColor *controlColor;
@property (nonatomic) CGFloat height;
@property (nonatomic) CGFloat displayLeftInset;
@property (nonatomic) CGFloat displayRightInset;
@property (nonatomic) CGFloat displayTopInset;
@property (nonatomic) CGFloat controlLeftInset;
@property (nonatomic) CGFloat controlTopInset;
@property (nonatomic) CGFloat closeRightInset;
@property (nonatomic) CGFloat closeTopInset;
+ (LGMusicPlayerAppearance *)brandedAppearanceDark:(BOOL)dark;
+ (LGMusicPlayerAppearance *)conversationAppearanceDark:(BOOL)dark compact:(BOOL)compact;
- (UIImage *)imageForGlyph:(LGMusicPlayerGlyph)glyph;
@end
