#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 50000
#if __has_include(<UIKit/UITextInput.h>)
#import <UIKit/UITextInput.h>
#else
@class UITextPosition;
@interface UITextRange : NSObject
@property (nonatomic, readonly) UITextPosition *end;
@end
#endif

@interface UITextView (LGTextInputCompatibility)
@property (nonatomic, readonly) UITextRange *selectedTextRange;
- (CGRect)caretRectForPosition:(UITextPosition *)position;
@end
#endif

#if __has_include(<CoreText/CoreText.h>)
#import <CoreText/CoreText.h>
#define LG_PLATFORM_HAS_CORETEXT 1
#else
#define LG_PLATFORM_HAS_CORETEXT 0

typedef CFTypeRef CTFontRef;
typedef CFTypeRef CTTypesetterRef;
typedef CFTypeRef CTLineRef;
typedef CFTypeRef CTRunRef;
typedef CFTypeRef CTRunDelegateRef;

typedef uint32_t CTLineTruncationType;
enum
{
    kCTLineTruncationStart = 0,
    kCTLineTruncationEnd = 1,
    kCTLineTruncationMiddle = 2
};

typedef uint32_t CTRunStatus;
enum
{
    kCTRunStatusNoStatus = 0,
    kCTRunStatusRightToLeft = 1 << 0
};

enum
{
    kCTUnderlineStyleNone = 0x00,
    kCTUnderlineStyleSingle = 0x01
};

enum
{
    kCTRunDelegateVersion1 = 1
};

typedef struct
{
    CFIndex version;
    void (*dealloc)(void *refCon);
    CGFloat (*getAscent)(void *refCon);
    CGFloat (*getDescent)(void *refCon);
    CGFloat (*getWidth)(void *refCon);
} CTRunDelegateCallbacks;

FOUNDATION_EXPORT const CFStringRef kCTFontAttributeName;
FOUNDATION_EXPORT const CFStringRef kCTForegroundColorAttributeName;
FOUNDATION_EXPORT const CFStringRef kCTForegroundColorFromContextAttributeName;
FOUNDATION_EXPORT const CFStringRef kCTUnderlineStyleAttributeName;
FOUNDATION_EXPORT const CFStringRef kCTRunDelegateAttributeName;

FOUNDATION_EXPORT CTFontRef CTFontCreateWithName(CFStringRef name, CGFloat size, const CGAffineTransform *matrix);
FOUNDATION_EXPORT CFStringRef CTFontCopyPostScriptName(CTFontRef font);
FOUNDATION_EXPORT CFCharacterSetRef CTFontCopyCharacterSet(CTFontRef font);
FOUNDATION_EXPORT CTFontRef CTFontCreateForString(CTFontRef font, CFStringRef string, CFRange range);
FOUNDATION_EXPORT CGFloat CTFontGetSize(CTFontRef font);
FOUNDATION_EXPORT CGFloat CTFontGetAscent(CTFontRef font);
FOUNDATION_EXPORT CGFloat CTFontGetDescent(CTFontRef font);
FOUNDATION_EXPORT CGFloat CTFontGetLeading(CTFontRef font);
FOUNDATION_EXPORT CGFloat CTFontGetCapHeight(CTFontRef font);

FOUNDATION_EXPORT CTTypesetterRef CTTypesetterCreateWithAttributedString(CFAttributedStringRef string);
FOUNDATION_EXPORT CFIndex CTTypesetterSuggestLineBreak(CTTypesetterRef typesetter, CFIndex startIndex, double width);
FOUNDATION_EXPORT CFIndex CTTypesetterSuggestClusterBreak(CTTypesetterRef typesetter, CFIndex startIndex, double width);
FOUNDATION_EXPORT CTLineRef CTTypesetterCreateLine(CTTypesetterRef typesetter, CFRange stringRange);
FOUNDATION_EXPORT CTLineRef CTTypesetterCreateLineWithOffset(CTTypesetterRef typesetter, CFRange stringRange, double offset);

FOUNDATION_EXPORT CTLineRef CTLineCreateWithAttributedString(CFAttributedStringRef string);
FOUNDATION_EXPORT CTLineRef CTLineCreateTruncatedLine(CTLineRef line, double width, CTLineTruncationType truncationType, CTLineRef truncationToken);
FOUNDATION_EXPORT CTLineRef CTLineCreateJustifiedLine(CTLineRef line, CGFloat justificationFactor, double justificationWidth);
FOUNDATION_EXPORT double CTLineGetTypographicBounds(CTLineRef line, CGFloat *ascent, CGFloat *descent, CGFloat *leading);
FOUNDATION_EXPORT double CTLineGetTrailingWhitespaceWidth(CTLineRef line);
FOUNDATION_EXPORT CFRange CTLineGetStringRange(CTLineRef line);
FOUNDATION_EXPORT CFArrayRef CTLineGetGlyphRuns(CTLineRef line);
FOUNDATION_EXPORT CGFloat CTLineGetOffsetForStringIndex(CTLineRef line, CFIndex charIndex, CGFloat *secondaryOffset);
FOUNDATION_EXPORT CGFloat CTLineGetPenOffsetForFlush(CTLineRef line, CGFloat flushFactor, double flushWidth);
FOUNDATION_EXPORT void CTLineDraw(CTLineRef line, CGContextRef context);

FOUNDATION_EXPORT CFDictionaryRef CTRunGetAttributes(CTRunRef run);
FOUNDATION_EXPORT CFIndex CTRunGetGlyphCount(CTRunRef run);
FOUNDATION_EXPORT double CTRunGetTypographicBounds(CTRunRef run, CFRange range, CGFloat *ascent, CGFloat *descent, CGFloat *leading);
FOUNDATION_EXPORT CFRange CTRunGetStringRange(CTRunRef run);
FOUNDATION_EXPORT void CTRunGetStringIndices(CTRunRef run, CFRange range, CFIndex buffer[]);
FOUNDATION_EXPORT void CTRunGetPositions(CTRunRef run, CFRange range, CGPoint buffer[]);
FOUNDATION_EXPORT CTRunStatus CTRunGetStatus(CTRunRef run);
FOUNDATION_EXPORT void CTRunDraw(CTRunRef run, CGContextRef context, CFRange range);

FOUNDATION_EXPORT CTRunDelegateRef CTRunDelegateCreate(const CTRunDelegateCallbacks *callbacks, void *refCon);
FOUNDATION_EXPORT void LGPlatformAttributedStringSetAttribute(CFMutableAttributedStringRef string, CFRange range, CFStringRef name, CFTypeRef value);

#define CFAttributedStringSetAttribute LGPlatformAttributedStringSetAttribute
#endif

FOUNDATION_EXPORT CTLineRef LGPlatformCreateTruncatedLine(CTTypesetterRef typesetter, CFAttributedStringRef string, CFRange range, double offset, double width, CTLineTruncationType truncationType, CFAttributedStringRef truncationToken, bool forceTruncationToken);

FOUNDATION_EXPORT NSString *LGPlatformDateFormatFromTemplate(NSString *templateString, NSUInteger options, NSLocale *locale);
FOUNDATION_EXPORT NSString *LGPlatformLocalizedStringFromDate(NSDate *date, NSDateFormatterStyle dateStyle, NSDateFormatterStyle timeStyle);
FOUNDATION_EXPORT BOOL LGPlatformLanguageIsRightToLeft(NSString *languageCode);
FOUNDATION_EXPORT CGSize LGPlatformTextSize(NSString *text, UIFont *font, CGSize constrainedSize, UILineBreakMode lineBreakMode);
FOUNDATION_EXPORT CGFloat LGPlatformFontLineHeight(UIFont *font);
FOUNDATION_EXPORT CGFloat LGPlatformFontCapHeight(UIFont *font);

FOUNDATION_EXPORT bool LGPlatformTextUsesManagedFallback(void);
FOUNDATION_EXPORT void LGPlatformTextApplyManagedFallback(CFMutableAttributedStringRef string);
FOUNDATION_EXPORT void LGPlatformTextWarmFallbackFonts(void);
FOUNDATION_EXPORT CTLineRef LGPlatformTextCreateLine(CFAttributedStringRef string);
FOUNDATION_EXPORT CTTypesetterRef LGPlatformTextCreateTypesetter(CFAttributedStringRef string);

FOUNDATION_EXPORT void LGPlatformTextLogSlowLayout(const char *site, CFAttributedStringRef string, CFTimeInterval duration);
