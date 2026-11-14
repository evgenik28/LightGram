#import "LGGeometry.h"
#import "../../LightGramPlatform/LGPlatformGraphics.h"

CGFloat LGPixelFloor(CGFloat value)
{
    return LGPlatformPixelFloor(value);
}

CGFloat LGPixelCeil(CGFloat value)
{
    return LGPlatformPixelCeil(value);
}

CGFloat LGPixelRound(CGFloat value)
{
    return LGPlatformPixelRound(value);
}

CGRect LGRectInsetEdges(CGRect rect, UIEdgeInsets insets)
{
    rect.origin.x += insets.left;
    rect.origin.y += insets.top;
    rect.size.width = MAX(0.0f, rect.size.width - insets.left - insets.right);
    rect.size.height = MAX(0.0f, rect.size.height - insets.top - insets.bottom);
    return rect;
}

CGRect LGRectCenterSize(CGRect bounds, CGSize size)
{
    return CGRectMake(LGPixelFloor(CGRectGetMidX(bounds) - size.width * 0.5f), LGPixelFloor(CGRectGetMidY(bounds) - size.height * 0.5f), size.width, size.height);
}

CGFloat LGClamp(CGFloat value, CGFloat minimum, CGFloat maximum)
{
    return MIN(MAX(value, minimum), maximum);
}
