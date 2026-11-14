#import <Foundation/Foundation.h>

extern NSString *const TGLightGramSettingsDidChangeNotification;
extern NSString *const TGLightGramSettingsChangedKey;

extern NSString *const TGLightGramSecretTranslatorDeepLKey;
extern NSString *const TGLightGramSecretTranslatorLLMKey;
extern NSString *const TGLightGramSettingGeneralShowSeconds;
extern NSString *const TGLightGramSettingGeneralTimeZoneManual;
extern NSString *const TGLightGramSettingGeneralTimeZoneOffset;
extern NSString *const TGLightGramSettingGeneralExactNumbers;
extern NSString *const TGLightGramSettingGeneralExactLastSeen;
extern NSString *const TGLightGramSettingGeneralFilterZalgo;
extern NSString *const TGLightGramSettingGeneralHidePhone;
extern NSString *const TGLightGramSettingGeneralNewChats;
extern NSString *const TGLightGramSettingGeneralMessageMenuStyle;
extern NSString *const TGLightGramSettingInterfaceModern;
extern NSString *const TGLightGramSettingGeneralShowPeerIds;
extern NSString *const TGLightGramSettingGeneralHideArchive;
extern NSString *const TGLightGramSettingGeneralDisableUnarchiveSwipe;
extern NSString *const TGLightGramSettingTranslatorShowButton;
extern NSString *const TGLightGramSettingTranslatorProvider;
extern NSString *const TGLightGramSettingTranslatorTargetLanguage;
extern NSString *const TGLightGramSettingTranslatorSkipLanguages;
extern NSString *const TGLightGramSettingTranslatorLLMEndpoint;
extern NSString *const TGLightGramSettingTranslatorLLMModel;
extern NSString *const TGLightGramSettingChatListCompact;
extern NSString *const TGLightGramSettingChatListTitleMode;
extern NSString *const TGLightGramSettingChatListCustomTitle;
extern NSString *const TGLightGramSettingChatListHideSearch;
extern NSString *const TGLightGramSettingChatListHideAllChatsTab;
extern NSString *const TGLightGramSettingChatListFolderTags;
extern NSString *const TGLightGramSettingMessagesBubbleRadius;
extern NSString *const TGLightGramSettingMessagesStickerScale;
extern NSString *const TGLightGramSettingMessagesHideStickerTime;
extern NSString *const TGLightGramSettingMessagesAnimatedEmoji;
extern NSString *const TGLightGramSettingMessagesAnimatedStickers;
extern NSString *const TGLightGramSettingMessagesReplyAuthorColor;
extern NSString *const TGLightGramSettingMessagesDoubleTapIncoming;
extern NSString *const TGLightGramSettingMessagesDoubleTapOutgoing;
extern NSString *const TGLightGramSettingMessagesQuickReaction;
extern NSString *const TGLightGramSettingMessagesEditedPencil;
extern NSString *const TGLightGramSettingMessagesMenuHiddenActions;
extern NSString *const TGLightGramSettingMessagesMenuScale;
extern NSString *const TGLightGramSettingAppearanceAvatarRoundness;
extern NSString *const TGLightGramSettingAppearanceRoundChatAvatar;
extern NSString *const TGLightGramSettingAppearanceSnowfall;
extern NSString *const TGLightGramSettingAppearanceNightSurface;
extern NSString *const TGLightGramSettingAppearanceSeparators;
extern NSString *const TGLightGramSettingConfirmCalls;
extern NSString *const TGLightGramSettingConfirmLinks;
extern NSString *const TGLightGramSettingConfirmVoiceMessages;
extern NSString *const TGLightGramSettingMessagesDeleteForMe;
extern NSString *const TGLightGramSettingMessagesNoLinkPreview;

@interface TGLightGramSettings : NSObject

+ (void)startApplyingRuntimeSettings;

+ (bool)boolForKey:(NSString *)key;
+ (void)setBool:(bool)value forKey:(NSString *)key;

+ (NSInteger)integerForKey:(NSString *)key;
+ (void)setInteger:(NSInteger)value forKey:(NSString *)key;

+ (NSString *)stringForKey:(NSString *)key;
+ (void)setString:(NSString *)value forKey:(NSString *)key;

+ (NSArray *)arrayForKey:(NSString *)key;
+ (void)setArray:(NSArray *)value forKey:(NSString *)key;

+ (void)resetValueForKey:(NSString *)key;

+ (NSString *)secretForKey:(NSString *)key;
+ (void)setSecret:(NSString *)secret forKey:(NSString *)key;

@end

#ifdef __cplusplus
extern "C" {
#endif

NSString *TGLightGramDisplayText(NSString *text);
NSString *TGLightGramEditedLabel(void);
bool TGLightGramSettingAffectsMessageAppearance(NSString *key);
NSString *TGLightGramOwnPhoneDisplay(NSString *formattedPhone);
bool TGLightGramUsesExactNumbers(void);
bool TGLightGramModernInterfaceEnabled(void);
int32_t TGLightGramDatacenterForPhotoUrl(NSString *photoUrl);
NSString *TGLightGramExactCountString(int64_t count);

#ifdef __cplusplus
}
#endif
