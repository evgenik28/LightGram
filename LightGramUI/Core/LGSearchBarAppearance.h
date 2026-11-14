#import <UIKit/UIKit.h>

@class LGSurfaceStyle;

@interface LGSearchBarAppearance : NSObject
@property (nonatomic, retain) LGSurfaceStyle *backgroundSurfaceStyle;
@property (nonatomic, retain) UIColor *backdropColor;
@property (nonatomic, retain) LGSurfaceStyle *fieldSurfaceStyle;
@property (nonatomic, retain) UIColor *textColor;
@property (nonatomic, retain) UIColor *placeholderColor;
@property (nonatomic, retain) UIColor *iconColor;
@property (nonatomic) CGFloat iconSize;
@property (nonatomic) CGFloat iconCircleDiameter;
@property (nonatomic) CGFloat iconLineWidth;
@property (nonatomic) UIOffset iconOffset;
@property (nonatomic) UIOffset placeholderOffset;
+ (LGSearchBarAppearance *)brandedAppearanceDark:(BOOL)dark;
+ (LGSearchBarAppearance *)contactAppearanceDark:(BOOL)dark;
@end
