#import <UIKit/UIKit.h>

FOUNDATION_EXPORT CGFloat LGPixelFloor(CGFloat value);
FOUNDATION_EXPORT CGFloat LGPixelCeil(CGFloat value);
FOUNDATION_EXPORT CGFloat LGPixelRound(CGFloat value);
FOUNDATION_EXPORT CGRect LGRectInsetEdges(CGRect rect, UIEdgeInsets insets);
FOUNDATION_EXPORT CGRect LGRectCenterSize(CGRect bounds, CGSize size);
FOUNDATION_EXPORT CGFloat LGClamp(CGFloat value, CGFloat minimum, CGFloat maximum);
