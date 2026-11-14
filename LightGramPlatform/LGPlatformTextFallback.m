#import "LGPlatformText.h"
#import "LGPlatformVersion.h"
#import "LGUnicode.h"
#include <pthread.h>
#import "LGPlatformDispatch.h"

void LGPlatformTextLogSlowLayout(const char *site, CFAttributedStringRef string, CFTimeInterval duration)
{
    if (!LGDiagnosticsEnabled() || duration < 0.1 || string == NULL)
        return;
    CFStringRef text = CFAttributedStringGetString(string);
    CFIndex length = text != NULL ? CFStringGetLength(text) : 0;
    NSMutableString *codes = [[NSMutableString alloc] init];
    for (CFIndex index = 0; index < length && codes.length < 400; index++)
    {
        UniChar character = CFStringGetCharacterAtIndex(text, index);
        if (character >= 0x80)
            [codes appendFormat:@"%04X ", (unsigned int)character];
    }
    LGPlatformDiagnosticLog(@"TEXTSLOW %s %.0fms length=%ld %@", site, duration * 1000.0, (long)length, codes);
}

#if LG_PLATFORM_HAS_CORETEXT

typedef struct
{
    uint32_t first;
    uint32_t last;
    const char *const *fonts;
} LGTextFallbackBlock;

static const char *const LGTextFallbackHebrewFonts[] = {"ArialHebrew", "ArialMT", NULL};
static const char *const LGTextFallbackArabicFonts[] = {"GeezaPro", NULL};
static const char *const LGTextFallbackThaiFonts[] = {"Thonburi", NULL};
static const char *const LGTextFallbackDevanagariFonts[] = {"DevanagariSangamMN", NULL};
static const char *const LGTextFallbackBengaliFonts[] = {"BanglaSangamMN", NULL};
static const char *const LGTextFallbackGurmukhiFonts[] = {"GurmukhiMN", NULL};
static const char *const LGTextFallbackGujaratiFonts[] = {"GujaratiSangamMN", NULL};
static const char *const LGTextFallbackOriyaFonts[] = {"OriyaSangamMN", NULL};
static const char *const LGTextFallbackTamilFonts[] = {"TamilSangamMN", NULL};
static const char *const LGTextFallbackTeluguFonts[] = {"TeluguSangamMN", NULL};
static const char *const LGTextFallbackKannadaFonts[] = {"KannadaSangamMN", NULL};
static const char *const LGTextFallbackMalayalamFonts[] = {"MalayalamSangamMN", NULL};
static const char *const LGTextFallbackSinhalaFonts[] = {"SinhalaSangamMN", NULL};
static const char *const LGTextFallbackHangulFonts[] = {"AppleSDGothicNeo-Medium", "AppleGothic", NULL};
static const char *const LGTextFallbackKanaFonts[] = {"HiraKakuProN-W3", "STHeitiSC-Light", NULL};
static const char *const LGTextFallbackHanFonts[] = {"STHeitiSC-Light", "STHeitiTC-Light", "HiraKakuProN-W3", NULL};
static const char *const LGTextFallbackSyllabicsFonts[] = {"EuphemiaUCAS", NULL};
static const char *const LGTextFallbackSymbolFonts[] = {"AppleColorEmoji", "ZapfDingbatsITC", "ArialMT", "Helvetica", "TimesNewRomanPSMT", NULL};
static const char *const LGTextFallbackEmojiFonts[] = {"AppleColorEmoji", NULL};
static const char *const LGTextFallbackGeneralFonts[] = {"Helvetica", "ArialMT", "TimesNewRomanPSMT", "Georgia", "CourierNewPSMT", "Verdana", "AppleColorEmoji", NULL};

static const LGTextFallbackBlock LGTextFallbackBlocks[] = {
    {0x0590, 0x05FF, LGTextFallbackHebrewFonts},
    {0x0600, 0x06FF, LGTextFallbackArabicFonts},
    {0x0750, 0x077F, LGTextFallbackArabicFonts},
    {0x0900, 0x097F, LGTextFallbackDevanagariFonts},
    {0x0980, 0x09FF, LGTextFallbackBengaliFonts},
    {0x0A00, 0x0A7F, LGTextFallbackGurmukhiFonts},
    {0x0A80, 0x0AFF, LGTextFallbackGujaratiFonts},
    {0x0B00, 0x0B7F, LGTextFallbackOriyaFonts},
    {0x0B80, 0x0BFF, LGTextFallbackTamilFonts},
    {0x0C00, 0x0C7F, LGTextFallbackTeluguFonts},
    {0x0C80, 0x0CFF, LGTextFallbackKannadaFonts},
    {0x0D00, 0x0D7F, LGTextFallbackMalayalamFonts},
    {0x0D80, 0x0DFF, LGTextFallbackSinhalaFonts},
    {0x0E00, 0x0E7F, LGTextFallbackThaiFonts},
    {0x1100, 0x11FF, LGTextFallbackHangulFonts},
    {0x1400, 0x167F, LGTextFallbackSyllabicsFonts},
    {0x2000, 0x2BFF, LGTextFallbackSymbolFonts},
    {0x2E80, 0x2FDF, LGTextFallbackHanFonts},
    {0x3000, 0x303F, LGTextFallbackHanFonts},
    {0x3040, 0x30FF, LGTextFallbackKanaFonts},
    {0x3100, 0x312F, LGTextFallbackHanFonts},
    {0x3130, 0x318F, LGTextFallbackHangulFonts},
    {0x3190, 0x31EF, LGTextFallbackHanFonts},
    {0x31F0, 0x31FF, LGTextFallbackKanaFonts},
    {0x3200, 0x4DBF, LGTextFallbackHanFonts},
    {0x4E00, 0x9FFF, LGTextFallbackHanFonts},
    {0xAC00, 0xD7AF, LGTextFallbackHangulFonts},
    {0xE000, 0xF8FF, LGTextFallbackEmojiFonts},
    {0xF900, 0xFAFF, LGTextFallbackHanFonts},
    {0xFB1D, 0xFB4F, LGTextFallbackHebrewFonts},
    {0xFB50, 0xFDFF, LGTextFallbackArabicFonts},
    {0xFE30, 0xFE4F, LGTextFallbackHanFonts},
    {0xFE70, 0xFEFE, LGTextFallbackArabicFonts},
    {0xFF00, 0xFFEF, LGTextFallbackKanaFonts},
    {0x1F000, 0x1FAFF, LGTextFallbackEmojiFonts},
    {0x20000, 0x2FFFF, LGTextFallbackHanFonts},
};

static const char *const *LGTextFallbackFontsForCodePoint(uint32_t codePoint)
{
    size_t count = sizeof(LGTextFallbackBlocks) / sizeof(LGTextFallbackBlocks[0]);
    for (size_t index = 0; index < count; index++)
    {
        if (codePoint >= LGTextFallbackBlocks[index].first && codePoint <= LGTextFallbackBlocks[index].last)
            return LGTextFallbackBlocks[index].fonts;
    }
    if (codePoint >= 0x10000)
        return NULL;
    return LGTextFallbackGeneralFonts;
}

static bool LGTextCodePointIsInvisible(uint32_t codePoint)
{
    return (codePoint >= 0x0300 && codePoint <= 0x036F) ||
        (codePoint >= 0x180B && codePoint <= 0x180E) ||
        (codePoint >= 0x200B && codePoint <= 0x200F) ||
        (codePoint >= 0x202A && codePoint <= 0x202E) ||
        (codePoint >= 0x2060 && codePoint <= 0x206F) ||
        (codePoint >= 0x20D0 && codePoint <= 0x20FF) ||
        (codePoint >= 0xFE00 && codePoint <= 0xFE0F) ||
        (codePoint >= 0xFE20 && codePoint <= 0xFE2F) ||
        codePoint == 0xFEFF ||
        (codePoint >= 0xFFF0 && codePoint <= 0xFFFB) ||
        (codePoint >= 0x1F3FB && codePoint <= 0x1F3FF) ||
        (codePoint >= 0xE0000 && codePoint <= 0xE0FFF);
}

static bool LGTextCodePointIsFormatControl(uint32_t codePoint)
{
    return (codePoint >= 0x180B && codePoint <= 0x180E) ||
        (codePoint >= 0x200B && codePoint <= 0x200F) ||
        (codePoint >= 0x202A && codePoint <= 0x202E) ||
        (codePoint >= 0x2060 && codePoint <= 0x206F) ||
        (codePoint >= 0xFE00 && codePoint <= 0xFE0F) ||
        codePoint == 0xFEFF ||
        (codePoint >= 0xE0000 && codePoint <= 0xE0FFF);
}

static const CTFontSymbolicTraits LGTextFontColorGlyphsTrait = (1 << 13);

static pthread_mutex_t LGTextFallbackMutex = PTHREAD_MUTEX_INITIALIZER;
static CFMutableDictionaryRef LGTextFallbackNamedFonts = NULL;
static CFMutableDictionaryRef LGTextFallbackCodePointFonts = NULL;
static CFMutableDictionaryRef LGTextFallbackSizedFonts = NULL;
static CTFontRef LGTextFallbackDefaultFont = NULL;
static CFMutableDictionaryRef LGTextFallbackStoredChoices = NULL;
static bool LGTextFallbackStoreSaveScheduled = false;

static NSString *LGTextFallbackStorePath(void)
{
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *system = [[[UIDevice currentDevice] systemVersion] stringByReplacingOccurrencesOfString:@"." withString:@"_"];
        path = [caches stringByAppendingPathComponent:[NSString stringWithFormat:@"LGTextFallback-%@.plist", system]];
    });
    return path;
}

static CFMutableDictionaryRef LGTextFallbackStoredChoicesLocked(void)
{
    if (LGTextFallbackStoredChoices != NULL)
        return LGTextFallbackStoredChoices;
    LGTextFallbackStoredChoices = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
    NSDictionary *stored = [NSDictionary dictionaryWithContentsOfFile:LGTextFallbackStorePath()];
    if ([stored isKindOfClass:[NSDictionary class]])
    {
        for (NSString *key in stored)
        {
            NSString *name = stored[key];
            if (![key isKindOfClass:[NSString class]] || ![name isKindOfClass:[NSString class]])
                continue;
            unsigned int codePoint = 0;
            if (![[NSScanner scannerWithString:key] scanHexInt:&codePoint] || codePoint == 0)
                continue;
            CFDictionarySetValue(LGTextFallbackStoredChoices, (const void *)(uintptr_t)codePoint, name.length != 0 ? (__bridge CFTypeRef)name : (CFTypeRef)kCFNull);
        }
    }
    return LGTextFallbackStoredChoices;
}

static void LGTextFallbackSaveStore(void)
{
    NSMutableDictionary *snapshot = [[NSMutableDictionary alloc] init];
    pthread_mutex_lock(&LGTextFallbackMutex);
    LGTextFallbackStoreSaveScheduled = false;
    CFDictionaryRef choices = LGTextFallbackStoredChoices;
    CFIndex count = choices != NULL ? CFDictionaryGetCount(choices) : 0;
    if (count != 0)
    {
        const void **keys = (const void **)malloc((size_t)count * sizeof(void *));
        const void **values = (const void **)malloc((size_t)count * sizeof(void *));
        if (keys != NULL && values != NULL)
        {
            CFDictionaryGetKeysAndValues(choices, keys, values);
            for (CFIndex index = 0; index < count; index++)
            {
                NSString *key = [NSString stringWithFormat:@"%lx", (unsigned long)(uintptr_t)keys[index]];
                snapshot[key] = values[index] == kCFNull ? @"" : [(__bridge NSString *)values[index] copy];
            }
        }
        free(keys);
        free(values);
    }
    pthread_mutex_unlock(&LGTextFallbackMutex);
    if (snapshot.count != 0)
        [snapshot writeToFile:LGTextFallbackStorePath() atomically:YES];
}

static void LGTextFallbackRememberChoiceLocked(uint32_t codePoint, CTFontRef font)
{
    CFMutableDictionaryRef choices = LGTextFallbackStoredChoicesLocked();
    CFTypeRef value = (CFTypeRef)kCFNull;
    CFStringRef name = font != NULL ? CTFontCopyPostScriptName(font) : NULL;
    if (name != NULL)
        value = name;
    CFDictionarySetValue(choices, (const void *)(uintptr_t)codePoint, value);
    if (name != NULL)
        CFRelease(name);
    if (LGTextFallbackStoreSaveScheduled)
        return;
    LGTextFallbackStoreSaveScheduled = true;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^
    {
        @autoreleasepool
        {
            LGTextFallbackSaveStore();
        }
    });
}

static bool LGTextFontCoversUnits(CTFontRef font, const UniChar *units, CFIndex count)
{
    if (font == NULL)
        return false;
    CGGlyph glyphs[2] = {0, 0};
    return CTFontGetGlyphsForCharacters(font, units, glyphs, count);
}

static bool LGTextFontDrawsNothing(CTFontRef font, const UniChar *units, CFIndex count)
{
    if (font == NULL || (CTFontGetSymbolicTraits(font) & LGTextFontColorGlyphsTrait) != 0)
        return false;
    CGGlyph glyphs[2] = {0, 0};
    if (!CTFontGetGlyphsForCharacters(font, units, glyphs, count))
        return false;
    for (CFIndex index = 0; index < count; index++)
    {
        if (glyphs[index] == 0)
            continue;
        CGPathRef path = CTFontCreatePathForGlyph(font, glyphs[index], NULL);
        if (path == NULL)
            continue;
        bool empty = CGPathIsEmpty(path);
        CGPathRelease(path);
        if (!empty)
            return false;
    }
    return true;
}

static CTFontRef LGTextFallbackNamedFontLocked(const char *name)
{
    if (LGTextFallbackNamedFonts == NULL)
        LGTextFallbackNamedFonts = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFStringRef key = CFStringCreateWithCString(kCFAllocatorDefault, name, kCFStringEncodingASCII);
    if (key == NULL)
        return NULL;
    CFTypeRef cached = CFDictionaryGetValue(LGTextFallbackNamedFonts, key);
    if (cached != NULL)
    {
        CFRelease(key);
        return cached == kCFNull ? NULL : (CTFontRef)cached;
    }

    CTFontRef font = CTFontCreateWithName(key, 16.0f, NULL);
    if (font != NULL)
    {
        CFStringRef postScriptName = CTFontCopyPostScriptName(font);
        bool matches = postScriptName != NULL && CFStringCompare(postScriptName, key, 0) == kCFCompareEqualTo;
        if (postScriptName != NULL)
            CFRelease(postScriptName);
        if (!matches)
        {
            CFRelease(font);
            font = NULL;
        }
    }
    CFDictionarySetValue(LGTextFallbackNamedFonts, key, font != NULL ? (CFTypeRef)font : (CFTypeRef)kCFNull);
    if (font != NULL)
        CFRelease(font);
    CFRelease(key);
    return font;
}

static CTFontRef LGTextFallbackFontForCodePointLocked(uint32_t codePoint, const UniChar *units, CFIndex count)
{
    if (LGTextFallbackCodePointFonts == NULL)
        LGTextFallbackCodePointFonts = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
    CFTypeRef cached = CFDictionaryGetValue(LGTextFallbackCodePointFonts, (const void *)(uintptr_t)codePoint);
    if (cached != NULL)
        return cached == kCFNull ? NULL : (CTFontRef)cached;

    CFTypeRef stored = CFDictionaryGetValue(LGTextFallbackStoredChoicesLocked(), (const void *)(uintptr_t)codePoint);
    if (stored == kCFNull)
    {
        CFDictionarySetValue(LGTextFallbackCodePointFonts, (const void *)(uintptr_t)codePoint, kCFNull);
        return NULL;
    }
    if (stored != NULL)
    {
        char name[128];
        if (CFStringGetCString((CFStringRef)stored, name, sizeof(name), kCFStringEncodingASCII))
        {
            CTFontRef storedFont = LGTextFallbackNamedFontLocked(name);
            if (LGTextFontCoversUnits(storedFont, units, count))
            {
                CFDictionarySetValue(LGTextFallbackCodePointFonts, (const void *)(uintptr_t)codePoint, storedFont);
                return storedFont;
            }
        }
    }

    CTFontRef result = NULL;
    const char *const *fonts = LGTextFallbackFontsForCodePoint(codePoint);
    for (size_t index = 0; fonts != NULL && fonts[index] != NULL && result == NULL; index++)
    {
        CTFontRef candidate = LGTextFallbackNamedFontLocked(fonts[index]);
        if (LGTextFontCoversUnits(candidate, units, count))
            result = candidate;
    }
    CFDictionarySetValue(LGTextFallbackCodePointFonts, (const void *)(uintptr_t)codePoint, result != NULL ? (CFTypeRef)result : (CFTypeRef)kCFNull);
    LGTextFallbackRememberChoiceLocked(codePoint, result);
    return result;
}

static CTFontRef LGTextFallbackCreateVerifiedFont(CFStringRef name)
{
    CTFontRef font = CTFontCreateWithName(name, 16.0f, NULL);
    if (font == NULL)
        return NULL;
    CFStringRef postScriptName = CTFontCopyPostScriptName(font);
    bool matches = postScriptName != NULL && CFStringCompare(postScriptName, name, 0) == kCFCompareEqualTo;
    if (postScriptName != NULL)
        CFRelease(postScriptName);
    if (!matches)
    {
        CFRelease(font);
        return NULL;
    }
    return font;
}

static void LGTextUnitsForCodePoint(uint32_t codePoint, UniChar *units, CFIndex *count)
{
    if (codePoint >= 0x10000)
    {
        uint32_t value = codePoint - 0x10000;
        units[0] = (UniChar)(0xD800 + (value >> 10));
        units[1] = (UniChar)(0xDC00 + (value & 0x3FF));
        *count = 2;
    }
    else
    {
        units[0] = (UniChar)codePoint;
        *count = 1;
    }
}

void LGPlatformTextWarmFallbackFonts(void)
{
    if (!LGPlatformTextUsesManagedFallback())
        return;

    NSMutableDictionary *namesToCodePoints = [[NSMutableDictionary alloc] init];
    pthread_mutex_lock(&LGTextFallbackMutex);
    CFMutableDictionaryRef choices = LGTextFallbackStoredChoicesLocked();
    CFIndex count = CFDictionaryGetCount(choices);
    if (count != 0)
    {
        const void **keys = (const void **)malloc((size_t)count * sizeof(void *));
        const void **values = (const void **)malloc((size_t)count * sizeof(void *));
        if (keys != NULL && values != NULL)
        {
            CFDictionaryGetKeysAndValues(choices, keys, values);
            for (CFIndex index = 0; index < count; index++)
            {
                if (values[index] == kCFNull)
                    continue;
                NSString *name = [(__bridge NSString *)values[index] copy];
                if (LGTextFallbackNamedFonts != NULL && CFDictionaryGetValue(LGTextFallbackNamedFonts, (__bridge CFStringRef)name) != NULL)
                    continue;
                NSMutableArray *codePoints = namesToCodePoints[name];
                if (codePoints == nil)
                {
                    codePoints = [[NSMutableArray alloc] init];
                    namesToCodePoints[name] = codePoints;
                }
                [codePoints addObject:@((uint32_t)(uintptr_t)keys[index])];
            }
        }
        free(keys);
        free(values);
    }
    pthread_mutex_unlock(&LGTextFallbackMutex);

    for (NSString *name in namesToCodePoints)
    {
        @autoreleasepool
        {
            CTFontRef font = LGTextFallbackCreateVerifiedFont((__bridge CFStringRef)name);
            NSArray *codePoints = namesToCodePoints[name];
            bool covers = false;
            if (font != NULL && codePoints.count != 0)
            {
                UniChar units[2] = {0, 0};
                CFIndex unitCount = 0;
                LGTextUnitsForCodePoint([codePoints[0] unsignedIntValue], units, &unitCount);
                covers = LGTextFontCoversUnits(font, units, unitCount);
            }

            pthread_mutex_lock(&LGTextFallbackMutex);
            if (LGTextFallbackNamedFonts == NULL)
                LGTextFallbackNamedFonts = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            if (CFDictionaryGetValue(LGTextFallbackNamedFonts, (__bridge CFStringRef)name) == NULL)
                CFDictionarySetValue(LGTextFallbackNamedFonts, (__bridge CFStringRef)name, font != NULL ? (CFTypeRef)font : (CFTypeRef)kCFNull);
            CTFontRef shared = (CTFontRef)CFDictionaryGetValue(LGTextFallbackNamedFonts, (__bridge CFStringRef)name);
            if (covers && shared != NULL && (CFTypeRef)shared != kCFNull)
            {
                if (LGTextFallbackCodePointFonts == NULL)
                    LGTextFallbackCodePointFonts = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
                for (NSNumber *codePoint in codePoints)
                {
                    const void *key = (const void *)(uintptr_t)[codePoint unsignedIntValue];
                    if (CFDictionaryGetValue(LGTextFallbackCodePointFonts, key) == NULL)
                        CFDictionarySetValue(LGTextFallbackCodePointFonts, key, shared);
                }
            }
            pthread_mutex_unlock(&LGTextFallbackMutex);
            if (font != NULL)
                CFRelease(font);
        }
    }
}

static CTFontRef LGTextFallbackSizedFontLocked(CTFontRef font, CGFloat size)
{
    if (LGTextFallbackSizedFonts == NULL)
        LGTextFallbackSizedFonts = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFStringRef postScriptName = CTFontCopyPostScriptName(font);
    if (postScriptName == NULL)
        return NULL;
    CFStringRef key = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@/%ld"), postScriptName, (long)lrint(size * 64.0f));
    CFRelease(postScriptName);
    if (key == NULL)
        return NULL;
    CTFontRef sized = (CTFontRef)CFDictionaryGetValue(LGTextFallbackSizedFonts, key);
    if (sized == NULL)
    {
        sized = CTFontCreateCopyWithAttributes(font, size, NULL, NULL);
        if (sized != NULL)
        {
            CFDictionarySetValue(LGTextFallbackSizedFonts, key, sized);
            CFRelease(sized);
        }
    }
    CFRelease(key);
    return sized;
}

static CTFontRef LGTextFallbackDefaultFontLocked(void)
{
    if (LGTextFallbackDefaultFont == NULL)
        LGTextFallbackDefaultFont = CTFontCreateWithName(CFSTR("Helvetica"), 12.0f, NULL);
    return LGTextFallbackDefaultFont;
}

static UniChar LGTextFallbackFillerForFontLocked(CTFontRef font, CTFontRef *outFillerFont)
{
    static const UniChar candidates[] = {0x200B, 0xFEFF, 0x2060};
    *outFillerFont = NULL;
    for (size_t index = 0; index < sizeof(candidates) / sizeof(candidates[0]); index++)
    {
        if (LGTextFontDrawsNothing(font, &candidates[index], 1))
            return candidates[index];
    }
    for (size_t index = 0; index < sizeof(candidates) / sizeof(candidates[0]); index++)
    {
        CTFontRef fallback = LGTextFallbackFontForCodePointLocked(candidates[index], &candidates[index], 1);
        if (LGTextFontDrawsNothing(fallback, &candidates[index], 1))
        {
            *outFillerFont = fallback;
            return candidates[index];
        }
    }
    return ' ';
}

static CFIndex LGTextFallbackCompatibilityReplacement(CTFontRef font, const UniChar *units, CFIndex count, UniChar *replacement)
{
    CFMutableStringRef string = CFStringCreateMutable(kCFAllocatorDefault, 0);
    if (string == NULL)
        return 0;
    CFStringAppendCharacters(string, units, count);
    CFStringNormalize(string, kCFStringNormalizationFormKC);
    CFIndex length = CFStringGetLength(string);
    CFIndex result = 0;
    if (length > 0 && length <= count)
    {
        UniChar normalized[2] = {0, 0};
        CFStringGetCharacters(string, CFRangeMake(0, length), normalized);
        bool changed = length != count || normalized[0] != units[0];
        bool covered = true;
        for (CFIndex index = 0; index < length && covered; index++)
        {
            if (normalized[index] >= 0x80 && !LGTextFontCoversUnits(font, &normalized[index], 1))
                covered = false;
        }
        if (changed && covered)
        {
            replacement[0] = normalized[0];
            if (length > 1)
                replacement[1] = normalized[1];
            result = length;
        }
    }
    CFRelease(string);
    return result;
}

bool LGPlatformTextUsesManagedFallback(void)
{
    static int value = -1;
    if (value < 0)
    {
        NSInteger majorVersion = LGPlatformMajorVersion();
        value = majorVersion >= 4 && majorVersion < 7 ? 1 : 0;
    }
    return value == 1;
}

void LGPlatformTextApplyManagedFallback(CFMutableAttributedStringRef string)
{
    if (string == NULL || !LGPlatformTextUsesManagedFallback())
        return;

    CFStringRef text = CFAttributedStringGetString(string);
    CFIndex length = text != NULL ? CFStringGetLength(text) : 0;
    if (length == 0)
        return;

    UniChar stackUnits[512];
    UniChar *units = length <= 512 ? stackUnits : (UniChar *)malloc((size_t)length * sizeof(UniChar));
    if (units == NULL)
        return;
    CFStringGetCharacters(text, CFRangeMake(0, length), units);

    CFIndex firstNonAscii = 0;
    while (firstNonAscii < length && units[firstNonAscii] < 0x80)
        firstNonAscii++;
    if (firstNonAscii == length)
    {
        if (units != stackUnits)
            free(units);
        return;
    }

    pthread_mutex_lock(&LGTextFallbackMutex);
    CFIndex index = 0;
    while (index < length)
    {
        CFRange runRange = CFRangeMake(0, 0);
        CTFontRef runFont = (CTFontRef)CFAttributedStringGetAttribute(string, index, kCTFontAttributeName, &runRange);
        CFIndex runEnd = runRange.location + runRange.length;
        if (runEnd <= index || runEnd > length)
            runEnd = length;
        if (runFont == NULL)
            runFont = LGTextFallbackDefaultFontLocked();
        if (runFont != NULL)
            CFRetain(runFont);
        CGFloat runSize = runFont != NULL ? CTFontGetSize(runFont) : 12.0f;

        while (index < runEnd)
        {
            UniChar unit = units[index];
            CFIndex count = 1;
            uint32_t codePoint = unit;
            if (LGUnicodeIsHighSurrogate(unit) && index + 1 < runEnd && LGUnicodeIsLowSurrogate(units[index + 1]))
            {
                count = 2;
                codePoint = LGUnicodeScalarForSurrogatePair(unit, units[index + 1]);
            }

            bool formatControl = LGTextCodePointIsFormatControl(codePoint);
            if (codePoint < 0x80 || (formatControl ? LGTextFontDrawsNothing(runFont, units + index, count) : LGTextFontCoversUnits(runFont, units + index, count)))
            {
                index += count;
                continue;
            }

            CTFontRef fallback = LGTextFallbackFontForCodePointLocked(codePoint, units + index, count);
            if (fallback != NULL && (!formatControl || LGTextFontDrawsNothing(fallback, units + index, count)))
            {
                CTFontRef sized = LGTextFallbackSizedFontLocked(fallback, runSize);
                if (sized != NULL)
                    CFAttributedStringSetAttribute(string, CFRangeMake(index, count), kCTFontAttributeName, sized);
                index += count;
                continue;
            }

            bool invisible = LGTextCodePointIsInvisible(codePoint);
            UniChar replacement[2] = {' ', ' '};
            CFIndex replacementLength = invisible ? 0 : LGTextFallbackCompatibilityReplacement(runFont, units + index, count, replacement);
            CTFontRef fillerFont = NULL;
            UniChar filler = LGTextFallbackFillerForFontLocked(runFont, &fillerFont);
            if (replacementLength == 0)
            {
                replacement[0] = invisible ? filler : ' ';
                replacementLength = 1;
            }
            for (CFIndex fillIndex = replacementLength; fillIndex < count; fillIndex++)
                replacement[fillIndex] = filler;

            CFStringRef replacementString = CFStringCreateWithCharacters(kCFAllocatorDefault, replacement, count);
            if (replacementString != NULL)
            {
                CFAttributedStringReplaceString(string, CFRangeMake(index, count), replacementString);
                CFRelease(replacementString);
                if (fillerFont != NULL)
                {
                    CTFontRef sizedFiller = LGTextFallbackSizedFontLocked(fillerFont, runSize);
                    for (CFIndex fillIndex = 0; fillIndex < count && sizedFiller != NULL; fillIndex++)
                    {
                        if (replacement[fillIndex] == filler)
                            CFAttributedStringSetAttribute(string, CFRangeMake(index + fillIndex, 1), kCTFontAttributeName, sizedFiller);
                    }
                }
            }
            index += count;
        }
        if (runFont != NULL)
            CFRelease(runFont);
    }
    pthread_mutex_unlock(&LGTextFallbackMutex);

    if (units != stackUnits)
        free(units);
}

static CFAttributedStringRef LGPlatformTextCreateManagedString(CFAttributedStringRef string)
{
    if (string == NULL || !LGPlatformTextUsesManagedFallback())
        return NULL;
    CFStringRef text = CFAttributedStringGetString(string);
    CFIndex length = text != NULL ? CFStringGetLength(text) : 0;
    bool hasNonAscii = false;
    if (length > 0)
    {
        CFStringInlineBuffer buffer;
        CFStringInitInlineBuffer(text, &buffer, CFRangeMake(0, length));
        for (CFIndex index = 0; index < length; index++)
        {
            if (CFStringGetCharacterFromInlineBuffer(&buffer, index) >= 0x80)
            {
                hasNonAscii = true;
                break;
            }
        }
    }
    if (!hasNonAscii)
        return NULL;
    CFMutableAttributedStringRef copy = CFAttributedStringCreateMutableCopy(kCFAllocatorDefault, 0, string);
    if (copy == NULL)
        return NULL;
    LGPlatformTextApplyManagedFallback(copy);
    return copy;
}

CTLineRef LGPlatformTextCreateLine(CFAttributedStringRef string)
{
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    CFAttributedStringRef managed = LGPlatformTextCreateManagedString(string);
    CTLineRef line = CTLineCreateWithAttributedString(managed != NULL ? managed : string);
    LGPlatformTextLogSlowLayout("line", managed != NULL ? managed : string, CFAbsoluteTimeGetCurrent() - start);
    if (managed != NULL)
        CFRelease(managed);
    return line;
}

CTTypesetterRef LGPlatformTextCreateTypesetter(CFAttributedStringRef string)
{
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    CFAttributedStringRef managed = LGPlatformTextCreateManagedString(string);
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString(managed != NULL ? managed : string);
    LGPlatformTextLogSlowLayout("typesetter", managed != NULL ? managed : string, CFAbsoluteTimeGetCurrent() - start);
    if (managed != NULL)
        CFRelease(managed);
    return typesetter;
}

#else

bool LGPlatformTextUsesManagedFallback(void)
{
    return false;
}

void LGPlatformTextWarmFallbackFonts(void)
{
}

void LGPlatformTextApplyManagedFallback(CFMutableAttributedStringRef string)
{
    (void)string;
}

CTLineRef LGPlatformTextCreateLine(CFAttributedStringRef string)
{
    return CTLineCreateWithAttributedString(string);
}

CTTypesetterRef LGPlatformTextCreateTypesetter(CFAttributedStringRef string)
{
    return CTTypesetterCreateWithAttributedString(string);
}

#endif
