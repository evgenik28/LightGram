#import "TGModernDateViewModel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#if __has_include(<CoreText/CoreText.h>)
#import <CoreText/CoreText.h>
#else
#import "LGPlatformText.h"
#endif
#import "TGPresentation.h"
#import "TGMessageViewModel.h"
#import "../LightGramUI/Core/LGConversationAppearance.h"

@interface TGModernDateViewModel ()
{
}

@end

@implementation TGModernDateViewModel

static CTFontRef TGModernDateViewModelCreateFont(UIFont *font)
{
    if (iosMajorVersion() >= 7)
        return OGCompatCreateCTFont(font);
    return CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, nil);
}

+ (CTFontRef)dateFont
{
    

    return [self dateFontWithBaseSize:12.0f];
}

+ (CTFontRef)inlineDateFont
{
    return [self dateFontWithBaseSize:11.0f];
}

+ (CTFontRef)dateFontWithBaseSize:(CGFloat)baseSize
{
    static NSMutableDictionary *fontsBySize = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        fontsBySize = [[NSMutableDictionary alloc] init];
    });

    CGFloat size = CGFloor(baseSize * TGMessageFontScale());
    NSNumber *key = @(size);
    @synchronized (fontsBySize)
    {
        id font = fontsBySize[key];
        if (font == nil)
        {
            CTFontRef createdFont = TGModernDateViewModelCreateFont(TGSystemFontOfSize(size));
            if (createdFont == NULL)
                return NULL;
            font = (__bridge_transfer id)createdFont;
            fontsBySize[key] = font;
        }
        return (__bridge CTFontRef)font;
    }
}

- (instancetype)initWithText:(NSString *)text textColor:(UIColor *)textColor daytimeVariant:(int)__unused daytimeVariant
{
    self = [super initWithText:text textColor:textColor font:[TGModernDateViewModel dateFont] maxWidth:CGFLOAT_MAX];
    if (self != nil)
    {
        self.hasNoView = true;
    }
    return self;
}

- (void)setText:(NSString *)text daytimeVariant:(int)__unused daytimeVariant
{
    [self setText:text maxWidth:CGFLOAT_MAX];
}

@end
