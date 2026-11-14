#import "TGLightGramSettings.h"
#import "TGNightPresentationPallete.h"
#import "TGPresentationCustomColors.h"

#import <pthread.h>
#include <stdlib.h>
#import <Security/Security.h>

#import "../submodules/LegacyComponents/LegacyComponents/TGDateUtils.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageInfo.h"

#import "TGPresentation.h"
#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

NSString *const TGLightGramSettingsDidChangeNotification = @"TGLightGramSettingsDidChangeNotification";
NSString *const TGLightGramSettingsChangedKey = @"key";

NSString *const TGLightGramSecretTranslatorDeepLKey = @"LightGram.Translator.DeepLKey";
NSString *const TGLightGramSecretTranslatorLLMKey = @"LightGram.Translator.LLMKey";
NSString *const TGLightGramSettingGeneralShowSeconds = @"LightGram.General.ShowSeconds";
NSString *const TGLightGramSettingGeneralTimeZoneManual = @"LightGram.General.TimeZoneManual";
NSString *const TGLightGramSettingGeneralTimeZoneOffset = @"LightGram.General.TimeZoneOffset";
NSString *const TGLightGramSettingGeneralExactNumbers = @"LightGram.General.ExactNumbers";
NSString *const TGLightGramSettingGeneralExactLastSeen = @"LightGram.General.ExactLastSeen";
NSString *const TGLightGramSettingGeneralFilterZalgo = @"LightGram.General.FilterZalgo";
NSString *const TGLightGramSettingGeneralNewChats = @"LightGram.General.NewChats";
NSString *const TGLightGramSettingGeneralMessageMenuStyle = @"LightGram.General.MessageMenuStyle";
NSString *const TGLightGramSettingGeneralHidePhone = @"LightGram.General.HidePhone";
NSString *const TGLightGramSettingInterfaceModern = @"LightGram.Interface.Modern";
NSString *const TGLightGramSettingGeneralShowPeerIds = @"LightGram.General.ShowPeerIds";
NSString *const TGLightGramSettingGeneralHideArchive = @"LightGram.General.HideArchive";
NSString *const TGLightGramSettingGeneralDisableUnarchiveSwipe = @"LightGram.General.DisableUnarchiveSwipe";
NSString *const TGLightGramSettingTranslatorShowButton = @"LightGram.Translator.ShowButton";
NSString *const TGLightGramSettingTranslatorProvider = @"LightGram.Translator.Provider";
NSString *const TGLightGramSettingTranslatorTargetLanguage = @"LightGram.Translator.TargetLanguage";
NSString *const TGLightGramSettingTranslatorSkipLanguages = @"LightGram.Translator.SkipLanguages";
NSString *const TGLightGramSettingTranslatorLLMEndpoint = @"LightGram.Translator.LLMEndpoint";
NSString *const TGLightGramSettingTranslatorLLMModel = @"LightGram.Translator.LLMModel";
NSString *const TGLightGramSettingChatListCompact = @"LightGram.ChatList.Compact";
NSString *const TGLightGramSettingChatListTitleMode = @"LightGram.ChatList.TitleMode";
NSString *const TGLightGramSettingChatListCustomTitle = @"LightGram.ChatList.CustomTitle";
NSString *const TGLightGramSettingChatListHideSearch = @"LightGram.ChatList.HideSearch";
NSString *const TGLightGramSettingChatListHideAllChatsTab = @"LightGram.ChatList.HideAllChatsTab";
NSString *const TGLightGramSettingChatListFolderTags = @"LightGram.ChatList.FolderTags";
NSString *const TGLightGramSettingMessagesBubbleRadius = @"LightGram.Messages.BubbleRadius";
NSString *const TGLightGramSettingMessagesStickerScale = @"LightGram.Messages.StickerScale";
NSString *const TGLightGramSettingMessagesHideStickerTime = @"LightGram.Messages.HideStickerTime";
NSString *const TGLightGramSettingMessagesAnimatedEmoji = @"LightGram.Messages.AnimatedEmoji";
NSString *const TGLightGramSettingMessagesAnimatedStickers = @"LightGram.Messages.AnimatedStickers";
NSString *const TGLightGramSettingMessagesReplyAuthorColor = @"LightGram.Messages.ReplyAuthorColor";
NSString *const TGLightGramSettingMessagesDoubleTapIncoming = @"LightGram.Messages.DoubleTapIncoming";
NSString *const TGLightGramSettingMessagesDoubleTapOutgoing = @"LightGram.Messages.DoubleTapOutgoing";
NSString *const TGLightGramSettingMessagesQuickReaction = @"LightGram.Messages.QuickReaction";
NSString *const TGLightGramSettingMessagesEditedPencil = @"LightGram.Messages.EditedPencil";
NSString *const TGLightGramSettingMessagesMenuScale = @"LightGram.Messages.MenuSize";
NSString *const TGLightGramSettingMessagesMenuHiddenActions = @"LightGram.Messages.MenuHiddenActions";
NSString *const TGLightGramSettingAppearanceAvatarRoundness = @"LightGram.Appearance.AvatarRoundness";
NSString *const TGLightGramSettingAppearanceRoundChatAvatar = @"LightGram.Appearance.RoundChatAvatar";
NSString *const TGLightGramSettingAppearanceSnowfall = @"LightGram.Appearance.Snowfall";
NSString *const TGLightGramSettingAppearanceNightSurface = @"LightGram.Appearance.NightSurface";
NSString *const TGLightGramSettingAppearanceSeparators = @"LightGram.Appearance.Separators";
NSString *const TGLightGramSettingConfirmCalls = @"LightGram.Confirm.Calls";
NSString *const TGLightGramSettingConfirmLinks = @"LightGram.Confirm.Links";
NSString *const TGLightGramSettingConfirmVoiceMessages = @"LightGram.Confirm.VoiceMessages";
NSString *const TGLightGramSettingMessagesDeleteForMe = @"LightGram.Messages.DeleteForMe";
NSString *const TGLightGramSettingMessagesNoLinkPreview = @"LightGram.Messages.NoLinkPreview";

typedef struct {
    NSInteger minimum;
    NSInteger maximum;
} TGLightGramSettingRange;

static pthread_mutex_t TGLightGramSettingsMutex = PTHREAD_MUTEX_INITIALIZER;

static NSValue *TGLightGramSettingRangeValue(NSInteger minimum, NSInteger maximum)
{
    TGLightGramSettingRange range = { minimum, maximum };
    return [NSValue valueWithBytes:&range objCType:@encode(TGLightGramSettingRange)];
}

static bool TGLightGramIsStackedMark(unichar character)
{
    return (character >= 0x0300 && character <= 0x036F) || (character >= 0x0483 && character <= 0x0489) || (character >= 0x1AB0 && character <= 0x1AFF) || (character >= 0x1DC0 && character <= 0x1DFF) || (character >= 0x20D0 && character <= 0x20FF) || (character >= 0xFE20 && character <= 0xFE2F);
}

NSString *TGLightGramDisplayText(NSString *text)
{
    if (text.length < 4 || ![TGLightGramSettings boolForKey:TGLightGramSettingGeneralFilterZalgo])
        return text;
    NSUInteger length = text.length;
    unichar *buffer = (unichar *)malloc(sizeof(unichar) * length);
    if (buffer == NULL)
        return text;
    [text getCharacters:buffer range:NSMakeRange(0, length)];
    bool changed = false;
    NSUInteger run = 0;
    for (NSUInteger index = 0; index < length; index++)
    {
        if (TGLightGramIsStackedMark(buffer[index]))
        {
            run++;
            if (run > 2)
            {
                buffer[index] = 0x2060;
                changed = true;
            }
        }
        else
        {
            run = 0;
        }
    }
    NSString *result = changed ? [[NSString alloc] initWithCharacters:buffer length:length] : text;
    free(buffer);
    return result;
}

NSString *TGLightGramOwnPhoneDisplay(NSString *formattedPhone)
{
    if (formattedPhone.length == 0 || ![TGLightGramSettings boolForKey:TGLightGramSettingGeneralHidePhone])
        return formattedPhone;
    NSMutableString *result = [[NSMutableString alloc] init];
    for (NSUInteger index = 0; index < formattedPhone.length; index++)
    {
        unichar character = [formattedPhone characterAtIndex:index];
        if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:character])
            [result appendString:@" "];
        else
            [result appendString:@"\u2022"];
    }
    return result;
}

int32_t TGLightGramDatacenterForPhotoUrl(NSString *photoUrl)
{
    if (photoUrl.length == 0)
        return 0;
    if ([photoUrl hasPrefix:@"peerphoto:"])
    {
        NSArray *components = [photoUrl componentsSeparatedByString:@":"];
        return components.count > 1 ? [components[1] intValue] : 0;
    }
    int datacenterId = 0;
    int64_t volumeId = 0;
    int localId = 0;
    int64_t secret = 0;
    return extractFileUrlComponents(photoUrl, &datacenterId, &volumeId, &localId, &secret) ? datacenterId : 0;
}

NSString *TGLightGramEditedLabel(void)
{
    return [TGLightGramSettings boolForKey:TGLightGramSettingMessagesEditedPencil] ? @"\u270E" : TGLocalized(@"Conversation.MessageEditedLabel");
}

bool TGLightGramSettingAffectsMessageAppearance(NSString *key)
{
    static NSSet *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        keys = [[NSSet alloc] initWithObjects:TGLightGramSettingMessagesAnimatedEmoji, TGLightGramSettingMessagesAnimatedStickers, TGLightGramSettingMessagesStickerScale, TGLightGramSettingMessagesHideStickerTime, TGLightGramSettingMessagesReplyAuthorColor, TGLightGramSettingMessagesEditedPencil, nil];
    });
    return key != nil && [keys containsObject:key];
}

bool TGLightGramUsesExactNumbers(void)
{
    return [TGLightGramSettings boolForKey:TGLightGramSettingGeneralExactNumbers];
}

bool TGLightGramModernInterfaceEnabled(void)
{
    return false;
}

NSString *TGLightGramExactCountString(int64_t count)
{
    static NSNumberFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.usesGroupingSeparator = true;
    });
    @synchronized (formatter)
    {
        return [formatter stringFromNumber:@(count)] ?: [[NSString alloc] initWithFormat:@"%lld", count];
    }
}

@implementation TGLightGramSettings

+ (void)startApplyingRuntimeSettings
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [self applyRuntimeSettings];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(runtimeSettingsChanged:) name:TGLightGramSettingsDidChangeNotification object:nil];
    });
}

+ (void)runtimeSettingsChanged:(NSNotification *)notification
{
    [self applyRuntimeSettings];
    [self runtimeSettingChanged:notification.userInfo[TGLightGramSettingsChangedKey]];
}

+ (void)runtimeSettingChanged:(NSString *)key
{
    if ([key isEqualToString:TGLightGramSettingMessagesBubbleRadius])
        [TGPresentation refreshAssets];
    else if ([key isEqualToString:TGLightGramSettingAppearanceNightSurface] || [key isEqualToString:TGLightGramSettingAppearanceSeparators])
        [TGPresentation reloadCustomColors];
}

+ (void)applyRuntimeSettings
{
    [TGDateUtils setShowsSeconds:[self boolForKey:TGLightGramSettingGeneralShowSeconds]];
    [TGDateUtils setPrefersExactLastSeen:[self boolForKey:TGLightGramSettingGeneralExactLastSeen]];
    [TGDateUtils setTimeZoneOffsetOverride:[self boolForKey:TGLightGramSettingGeneralTimeZoneManual] minutes:[self integerForKey:TGLightGramSettingGeneralTimeZoneOffset]];
    NSInteger roundness = [self integerForKey:TGLightGramSettingAppearanceAvatarRoundness];
    [TGLetteredAvatarView setCornerRoundness:roundness < 0 ? -1.0f : (CGFloat)roundness / 100.0f];
    [TGNightPresentationPallete setSurfaceTone:[self integerForKey:TGLightGramSettingAppearanceNightSurface]];
    [TGPresentationCustomColors setSeparatorsHidden:![self boolForKey:TGLightGramSettingAppearanceSeparators]];
}

+ (NSDictionary *)defaults
{
    static NSDictionary *defaults = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        defaults = @{
            TGLightGramSettingGeneralShowSeconds: @false,
            TGLightGramSettingGeneralTimeZoneManual: @false,
            TGLightGramSettingGeneralTimeZoneOffset: @0,
            TGLightGramSettingGeneralExactNumbers: @false,
            TGLightGramSettingGeneralExactLastSeen: @false,
            TGLightGramSettingGeneralFilterZalgo: @false,
            TGLightGramSettingGeneralHidePhone: @false,
            TGLightGramSettingGeneralNewChats: @true,
            TGLightGramSettingGeneralMessageMenuStyle: @0,
            TGLightGramSettingInterfaceModern: @false,
            TGLightGramSettingGeneralShowPeerIds: @false,
            TGLightGramSettingGeneralHideArchive: @false,
            TGLightGramSettingGeneralDisableUnarchiveSwipe: @false,
            TGLightGramSettingTranslatorShowButton: @false,
            TGLightGramSettingTranslatorProvider: @0,
            TGLightGramSettingTranslatorTargetLanguage: @"",
            TGLightGramSettingTranslatorSkipLanguages: @[],
            TGLightGramSettingTranslatorLLMEndpoint: @"https://api.openai.com/v1",
            TGLightGramSettingTranslatorLLMModel: @"gpt-4o-mini",
            TGLightGramSettingChatListCompact: @false,
            TGLightGramSettingChatListTitleMode: @0,
            TGLightGramSettingChatListCustomTitle: @"",
            TGLightGramSettingChatListHideSearch: @false,
            TGLightGramSettingChatListHideAllChatsTab: @false,
            TGLightGramSettingChatListFolderTags: @0,
            TGLightGramSettingMessagesBubbleRadius: @(-1),
            TGLightGramSettingMessagesStickerScale: @100,
            TGLightGramSettingMessagesHideStickerTime: @false,
            TGLightGramSettingMessagesAnimatedEmoji: @true,
            TGLightGramSettingMessagesAnimatedStickers: @true,
            TGLightGramSettingMessagesReplyAuthorColor: @false,
            TGLightGramSettingMessagesDoubleTapIncoming: @0,
            TGLightGramSettingMessagesDoubleTapOutgoing: @0,
            TGLightGramSettingMessagesQuickReaction: @"❤️",
            TGLightGramSettingMessagesEditedPencil: @false,
            TGLightGramSettingMessagesMenuHiddenActions: @[],
            TGLightGramSettingMessagesMenuScale: @100,
            TGLightGramSettingAppearanceAvatarRoundness: @(-1),
            TGLightGramSettingAppearanceRoundChatAvatar: @false,
            TGLightGramSettingAppearanceSnowfall: @(-1),
            TGLightGramSettingAppearanceNightSurface: @0,
            TGLightGramSettingAppearanceSeparators: @true,
            TGLightGramSettingConfirmCalls: @false,
            TGLightGramSettingConfirmLinks: @0,
            TGLightGramSettingConfirmVoiceMessages: @false,
            TGLightGramSettingMessagesDeleteForMe: @false,
            TGLightGramSettingMessagesNoLinkPreview: @false
        };
    });
    return defaults;
}

+ (NSDictionary *)ranges
{
    static NSDictionary *ranges = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        ranges = @{
            TGLightGramSettingGeneralTimeZoneOffset: TGLightGramSettingRangeValue(-720, 840),
            TGLightGramSettingTranslatorProvider: TGLightGramSettingRangeValue(0, 3),
            TGLightGramSettingChatListTitleMode: TGLightGramSettingRangeValue(0, 3),
            TGLightGramSettingChatListFolderTags: TGLightGramSettingRangeValue(0, 2),
            TGLightGramSettingMessagesBubbleRadius: TGLightGramSettingRangeValue(-1, 16),
            TGLightGramSettingMessagesStickerScale: TGLightGramSettingRangeValue(50, 130),
            TGLightGramSettingMessagesMenuScale: TGLightGramSettingRangeValue(70, 130),
            TGLightGramSettingMessagesDoubleTapIncoming: TGLightGramSettingRangeValue(0, 5),
            TGLightGramSettingMessagesDoubleTapOutgoing: TGLightGramSettingRangeValue(0, 6),
            TGLightGramSettingAppearanceAvatarRoundness: TGLightGramSettingRangeValue(-1, 100),
            TGLightGramSettingAppearanceSnowfall: TGLightGramSettingRangeValue(-1, 1),
            TGLightGramSettingAppearanceNightSurface: TGLightGramSettingRangeValue(0, 4),
            TGLightGramSettingConfirmLinks: TGLightGramSettingRangeValue(0, 2)
        };
    });
    return ranges;
}

+ (NSMutableDictionary *)cache
{
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });
    return cache;
}

+ (id)valueForKey:(NSString *)key ofClass:(Class)valueClass
{
    pthread_mutex_lock(&TGLightGramSettingsMutex);
    NSMutableDictionary *cache = [self cache];
    id value = cache[key];
    if (value == nil)
    {
        value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
        if (![value isKindOfClass:valueClass])
            value = [self defaults][key];
        if (value == nil)
            value = [NSNull null];
        cache[key] = value;
    }
    pthread_mutex_unlock(&TGLightGramSettingsMutex);
    return value == [NSNull null] ? nil : value;
}

+ (void)storeValue:(id)value forKey:(NSString *)key
{
    pthread_mutex_lock(&TGLightGramSettingsMutex);
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (value == nil)
        [userDefaults removeObjectForKey:key];
    else
        [userDefaults setObject:value forKey:key];
    [[self cache] removeObjectForKey:key];
    pthread_mutex_unlock(&TGLightGramSettingsMutex);
    [userDefaults synchronize];

    void (^post)(void) = ^
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:TGLightGramSettingsDidChangeNotification object:nil userInfo:@{TGLightGramSettingsChangedKey: key}];
    };
    if ([NSThread isMainThread])
        post();
    else
        dispatch_async(dispatch_get_main_queue(), post);
}

+ (bool)boolForKey:(NSString *)key
{
    return [[self valueForKey:key ofClass:[NSNumber class]] boolValue];
}

+ (void)setBool:(bool)value forKey:(NSString *)key
{
    [self storeValue:@(value) forKey:key];
}

+ (NSInteger)clampedInteger:(NSInteger)value forKey:(NSString *)key
{
    NSValue *rangeValue = [self ranges][key];
    if (rangeValue == nil)
        return value;
    TGLightGramSettingRange range;
    [rangeValue getValue:&range];
    return MAX(range.minimum, MIN(range.maximum, value));
}

+ (NSInteger)integerForKey:(NSString *)key
{
    return [self clampedInteger:[[self valueForKey:key ofClass:[NSNumber class]] integerValue] forKey:key];
}

+ (void)setInteger:(NSInteger)value forKey:(NSString *)key
{
    [self storeValue:@([self clampedInteger:value forKey:key]) forKey:key];
}

+ (NSString *)stringForKey:(NSString *)key
{
    return [self valueForKey:key ofClass:[NSString class]] ?: @"";
}

+ (void)setString:(NSString *)value forKey:(NSString *)key
{
    [self storeValue:[value copy] forKey:key];
}

+ (NSArray *)arrayForKey:(NSString *)key
{
    return [self valueForKey:key ofClass:[NSArray class]] ?: @[];
}

+ (void)setArray:(NSArray *)value forKey:(NSString *)key
{
    [self storeValue:[value copy] forKey:key];
}

+ (void)resetValueForKey:(NSString *)key
{
    [self storeValue:nil forKey:key];
}

+ (NSMutableDictionary *)secretQueryForKey:(NSString *)key
{
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
    query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    query[(__bridge id)kSecAttrService] = @"LightGram.Settings";
    query[(__bridge id)kSecAttrAccount] = key;
    return query;
}

+ (NSString *)secretForKey:(NSString *)key
{
    NSMutableDictionary *query = [self secretQueryForKey:key];
    query[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) != errSecSuccess || result == NULL)
        return @"";
    NSData *data = (__bridge_transfer NSData *)result;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

+ (void)setSecret:(NSString *)secret forKey:(NSString *)key
{
    NSMutableDictionary *query = [self secretQueryForKey:key];
    SecItemDelete((__bridge CFDictionaryRef)query);
    if (secret.length != 0)
    {
        query[(__bridge id)kSecValueData] = [secret dataUsingEncoding:NSUTF8StringEncoding];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
#endif
        SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:TGLightGramSettingsDidChangeNotification object:nil userInfo:@{TGLightGramSettingsChangedKey: key}];
}

@end
