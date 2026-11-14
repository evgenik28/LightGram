#import "TGLightGramSettingsPages.h"
#import "TGAppDelegate.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGSwitchCollectionItem.h"
#import "TGLightGramSettings.h"
#import "TGTelegramNetworking.h"
#import "TGCustomAlertView.h"
#import "TLRPCmessages_sendMessage_manual.h"
#import "TLBool.h"
#import "TGMessageContextMenu.h"
#import "TGLightGramSliderCollectionItem.h"
#import "TGLightGramTranslator.h"
#import "TGCrashReportCenter.h"
#import "TGLightGramAvatarPreviewCollectionItem.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMessage.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDocumentMediaAttachment.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGReplyMessageMediaAttachment.h"

#import "TGPresentation.h"
#import "TGPresentationAssets.h"
#import "TGAppearancePreviewCollectionItem.h"
#import "TGAnimatedEmojiStore.h"
#import "TGLightGramUpdateController.h"
#import "TGPluginsController.h"

NSArray *TGLightGramDoubleTapActions(bool outgoing)
{
    NSArray *actions = @[@"none", @"reply", @"reaction", @"forward", @"copy", @"translate"];
    return outgoing ? [actions arrayByAddingObject:@"edit"] : actions;
}

NSArray *TGLightGramMenuActionIdentifiers(void)
{
    return @[@"reply", @"copy", @"forward", @"pin", @"copyLink", @"reaction", @"select", @"report"];
}

static NSString *TGLightGramMenuActionTitle(NSString *identifier)
{
    return TGLocalized([@"LightGramSettings.Menu." stringByAppendingString:identifier]);
}

static NSString *TGLightGramDoubleTapTitle(NSString *identifier)
{
    return TGLocalized([@"LightGramSettings.DoubleTap." stringByAppendingString:identifier]);
}

static NSString *TGLightGramTimeZoneTitle(NSInteger minutes)
{
    NSInteger absolute = minutes < 0 ? -minutes : minutes;
    return [[NSString alloc] initWithFormat:@"UTC%@%02d:%02d", minutes < 0 ? @"−" : @"+", (int)(absolute / 60), (int)(absolute % 60)];
}

@interface TGLightGramRootSettingsController () <TGInterfaceRebuildRestorable>

@end

@implementation TGLightGramRootSettingsController

- (instancetype)init
{
    return [super initWithTitle:TGLocalized(@"LightGramSettings.Title")];
}

- (UIViewController *)controllerForInterfaceRebuild
{
    TGLightGramRootSettingsController *controller = [[TGLightGramRootSettingsController alloc] init];
    controller.presentation = [TGPresentation current];
    return controller;
}

- (void)pushSettingsController:(TGLightGramSettingsController *)controller
{
    controller.presentation = self.presentation;
    [self.navigationController pushViewController:controller animated:true];
}

- (NSArray *)buildSections
{
    __weak TGLightGramRootSettingsController *weakSelf = self;
    NSMutableArray *sections = [[NSMutableArray alloc] init];

    [sections addObject:[self sectionWithHeader:nil items:@[
        [self actionWithTitle:TGLocalized(@"LightGramSettings.General") variant:nil pressed:^
        {
            [weakSelf pushSettingsController:[[TGLightGramGeneralSettingsController alloc] init]];
        }],
        [self actionWithTitle:TGLocalized(@"LightGramSettings.Messages") variant:nil pressed:^
        {
            [weakSelf pushSettingsController:[[TGLightGramMessagesSettingsController alloc] init]];
        }]
    ] footer:nil]];

#if LG_PLUGINS_AVAILABLE
    [sections addObject:[self sectionWithHeader:nil items:@[
        [self actionWithTitle:TGLocalized(@"LightGramPlugins.Title") variant:nil pressed:^
        {
            [weakSelf pushSettingsController:[[TGPluginsController alloc] init]];
        }]
    ] footer:nil]];
#endif

    [sections addObject:[self sectionWithHeader:nil items:@[
        [self actionWithTitle:TGLocalized(@"LightGramUpdate.Title") variant:[TGLightGramUpdateController statusVariant] pressed:^
        {
            [weakSelf pushSettingsController:[[TGLightGramUpdateController alloc] init]];
        }]
    ] footer:nil]];


    if (TGCurrentInterfaceStyle() != 0)
    {
        TGLightGramAvatarPreviewCollectionItem *previewItem = [[TGLightGramAvatarPreviewCollectionItem alloc] init];
        TGLightGramSliderCollectionItem *roundnessItem = [self sliderWithTitle:TGLocalized(@"LightGramSettings.AvatarRoundness") key:TGLightGramSettingAppearanceAvatarRoundness minimumValue:-1 maximumValue:100 formatter:^NSString *(NSInteger value)
        {
            return value < 0 ? TGLocalized(@"LightGramSettings.Default") : [[NSString alloc] initWithFormat:@"%d%%", (int)value];
        }];
        __weak TGLightGramAvatarPreviewCollectionItem *weakPreviewItem = previewItem;
        roundnessItem.valueChanged = ^(NSInteger value)
        {
            [TGLetteredAvatarView setCornerRoundness:value < 0 ? -1.0f : (CGFloat)value / 100.0f];
            [weakPreviewItem refresh];
        };
        [sections addObject:[self sectionWithHeader:TGLocalized(@"LightGramSettings.Avatars") items:@[previewItem, roundnessItem] footer:TGLocalized(@"LightGramSettings.AvatarsInfo")]];
    }

    return sections;
}

@end

@implementation TGLightGramGeneralSettingsController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGAutoDownloadPreferencesDidChangeNotification object:nil];
}

- (instancetype)init
{
    self = [super initWithTitle:TGLocalized(@"LightGramSettings.General")];
    if (self != nil)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(automaticDownloadSettingsChanged:) name:TGAutoDownloadPreferencesDidChangeNotification object:nil];
    return self;
}

- (void)automaticDownloadSettingsChanged:(NSNotification *)notification
{
    __weak TGLightGramGeneralSettingsController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong TGLightGramGeneralSettingsController *strongSelf = weakSelf;
        if (strongSelf.isViewLoaded && strongSelf.view.window != nil)
            [strongSelf rebuild];
    });
}

- (bool)rebuildsForSettingKey:(NSString *)key
{
    return [key hasPrefix:@"LightGram.Translator."] || [key isEqualToString:TGLightGramSettingGeneralTimeZoneManual] || [key isEqualToString:TGLightGramSettingGeneralTimeZoneOffset] || [key isEqualToString:TGLightGramSettingGeneralNewChats] || [key isEqualToString:TGLightGramSettingGeneralMessageMenuStyle];
}

- (NSArray *)buildSections
{
    __weak TGLightGramGeneralSettingsController *weakSelf = self;
    NSMutableArray *sections = [[NSMutableArray alloc] init];

    [sections addObject:[self sectionWithHeader:nil items:@[
        [self switchWithTitle:TGLocalized(@"ChatSettings.AutoDownloadEnabled") value:!TGAppDelegateInstance.autoDownloadPreferences.disabled toggled:^(bool value)
        {
            TGAutoDownloadPreferences *preferences = TGAppDelegateInstance.autoDownloadPreferences;
            if (value && (preferences.photos | preferences.videos | preferences.documents | preferences.gifs | preferences.voiceMessages | preferences.videoMessages) == TGAutoDownloadModeNone)
                preferences = [TGAutoDownloadPreferences defaultPreferences];
            TGAppDelegateInstance.autoDownloadPreferences = [preferences updateDisabled:!value];
        }]
    ] footer:TGLocalized(@"LightGramSettings.AutoDownload.AutomaticInfo")]];

    NSMutableArray *translatorItems = [[NSMutableArray alloc] init];
    [translatorItems addObject:[self switchWithTitle:TGLocalized(@"LightGramSettings.TranslateButton") key:TGLightGramSettingTranslatorShowButton description:TGLocalized(@"LightGramSettings.TranslateButtonInfo")]];
    [translatorItems addObject:[self choiceWithTitle:TGLocalized(@"LightGramSettings.TranslateProvider") key:TGLightGramSettingTranslatorProvider options:[TGLightGramTranslator providerTitles] description:TGLocalized(@"LightGramSettings.TranslateProviderInfo")]];

    NSString *target = [TGLightGramSettings stringForKey:TGLightGramSettingTranslatorTargetLanguage];
    [translatorItems addObject:[self actionWithTitle:TGLocalized(@"LightGramSettings.TranslateTarget") variant:target.length == 0 ? TGLocalized(@"LightGramSettings.TranslateTargetApp") : [TGLightGramTranslator displayNameForLanguage:target] description:TGLocalized(@"LightGramSettings.TranslateTargetInfo") pressed:^
    {
        __strong TGLightGramGeneralSettingsController *strongSelf = weakSelf;
        NSArray *codes = [TGLightGramTranslator languageCodes];
        NSMutableArray *options = [[NSMutableArray alloc] initWithObjects:TGLocalized(@"LightGramSettings.TranslateTargetApp"), nil];
        for (NSString *code in codes)
            [options addObject:[TGLightGramTranslator displayNameForLanguage:code]];
        NSString *current = [TGLightGramSettings stringForKey:TGLightGramSettingTranslatorTargetLanguage];
        NSUInteger index = [codes indexOfObject:current];
        [strongSelf pushChoiceWithTitle:TGLocalized(@"LightGramSettings.TranslateTarget") options:options selectedIndex:current.length == 0 || index == NSNotFound ? 0 : (NSInteger)index + 1 footer:nil completion:^(NSInteger selected)
        {
            [TGLightGramSettings setString:selected <= 0 ? @"" : codes[(NSUInteger)selected - 1] forKey:TGLightGramSettingTranslatorTargetLanguage];
        }];
    }]];

    NSArray *skipped = [TGLightGramSettings arrayForKey:TGLightGramSettingTranslatorSkipLanguages];
    [translatorItems addObject:[self actionWithTitle:TGLocalized(@"LightGramSettings.TranslateSkip") variant:skipped.count == 0 ? TGLocalized(@"LightGramSettings.None") : [[NSString alloc] initWithFormat:@"%d", (int)skipped.count] description:TGLocalized(@"LightGramSettings.TranslateSkipInfo") pressed:^
    {
        __strong TGLightGramGeneralSettingsController *strongSelf = weakSelf;
        NSArray *codes = [TGLightGramTranslator languageCodes];
        NSMutableArray *options = [[NSMutableArray alloc] init];
        NSMutableIndexSet *selected = [[NSMutableIndexSet alloc] init];
        NSArray *current = [TGLightGramSettings arrayForKey:TGLightGramSettingTranslatorSkipLanguages];
        [codes enumerateObjectsUsingBlock:^(NSString *code, NSUInteger index, __unused BOOL *stop)
        {
            [options addObject:[TGLightGramTranslator displayNameForLanguage:code]];
            if ([current containsObject:code])
                [selected addIndex:index];
        }];
        [strongSelf pushMultipleChoiceWithTitle:TGLocalized(@"LightGramSettings.TranslateSkip") options:options selectedIndices:selected footer:TGLocalized(@"LightGramSettings.TranslateSkipInfo") completion:^(NSIndexSet *indices)
        {
            NSMutableArray *values = [[NSMutableArray alloc] init];
            [indices enumerateIndexesUsingBlock:^(NSUInteger index, __unused BOOL *stop)
            {
                [values addObject:codes[index]];
            }];
            [TGLightGramSettings setArray:values forKey:TGLightGramSettingTranslatorSkipLanguages];
        }];
    }]];

    TGLightGramTranslatorProvider provider = (TGLightGramTranslatorProvider)[TGLightGramSettings integerForKey:TGLightGramSettingTranslatorProvider];
    if (provider == TGLightGramTranslatorProviderDeepL || provider == TGLightGramTranslatorProviderLLM)
    {
        NSString *secretKey = provider == TGLightGramTranslatorProviderDeepL ? TGLightGramSecretTranslatorDeepLKey : TGLightGramSecretTranslatorLLMKey;
        bool hasKey = [TGLightGramSettings secretForKey:secretKey].length != 0;
        [translatorItems addObject:[self actionWithTitle:TGLocalized(@"LightGramSettings.TranslateKey") variant:hasKey ? TGLocalized(@"LightGramSettings.KeySet") : TGLocalized(@"LightGramSettings.KeyMissing") description:TGLocalized(@"LightGramSettings.TranslateKeyInfo") pressed:^
        {
            __strong TGLightGramGeneralSettingsController *strongSelf = weakSelf;
            [strongSelf pushTextInputWithTitle:TGLocalized(@"LightGramSettings.TranslateKey") text:[TGLightGramSettings secretForKey:secretKey] placeholder:TGLocalized(@"LightGramSettings.TranslateKeyPlaceholder") secure:true footer:TGLocalized(provider == TGLightGramTranslatorProviderDeepL ? @"LightGramSettings.TranslateKeyDeepLInfo" : @"LightGramSettings.TranslateKeyLLMInfo") completion:^(NSString *text)
            {
                [TGLightGramSettings setSecret:text forKey:secretKey];
            }];
        }]];
    }
    if (provider == TGLightGramTranslatorProviderLLM)
    {
        [translatorItems addObject:[self actionWithTitle:TGLocalized(@"LightGramSettings.TranslateEndpoint") variant:[[NSURL URLWithString:[TGLightGramSettings stringForKey:TGLightGramSettingTranslatorLLMEndpoint]] host] ?: @"" description:TGLocalized(@"LightGramSettings.TranslateEndpointInfo") pressed:^
        {
            __strong TGLightGramGeneralSettingsController *strongSelf = weakSelf;
            [strongSelf pushTextInputWithTitle:TGLocalized(@"LightGramSettings.TranslateEndpoint") text:[TGLightGramSettings stringForKey:TGLightGramSettingTranslatorLLMEndpoint] placeholder:@"https://api.openai.com/v1" secure:false footer:TGLocalized(@"LightGramSettings.TranslateEndpointInfo") completion:^(NSString *text)
            {
                if (text.length != 0)
                    [TGLightGramSettings setString:text forKey:TGLightGramSettingTranslatorLLMEndpoint];
            }];
        }]];
        [translatorItems addObject:[self actionWithTitle:TGLocalized(@"LightGramSettings.TranslateModel") variant:[TGLightGramSettings stringForKey:TGLightGramSettingTranslatorLLMModel] pressed:^
        {
            __strong TGLightGramGeneralSettingsController *strongSelf = weakSelf;
            [strongSelf pushTextInputWithTitle:TGLocalized(@"LightGramSettings.TranslateModel") text:[TGLightGramSettings stringForKey:TGLightGramSettingTranslatorLLMModel] placeholder:@"gpt-4o-mini" secure:false footer:nil completion:^(NSString *text)
            {
                if (text.length != 0)
                    [TGLightGramSettings setString:text forKey:TGLightGramSettingTranslatorLLMModel];
            }];
        }]];
    }
    [sections addObject:[self sectionWithHeader:TGLocalized(@"LightGramSettings.TranslateHeader") items:translatorItems footer:nil]];

    bool manualZone = [TGLightGramSettings boolForKey:TGLightGramSettingGeneralTimeZoneManual];
    NSString *zoneVariant = manualZone ? TGLightGramTimeZoneTitle([TGLightGramSettings integerForKey:TGLightGramSettingGeneralTimeZoneOffset]) : TGLocalized(@"LightGramSettings.TimeZoneAutomatic");
    TGLightGramActionCollectionItem *zoneItem = [self actionWithTitle:TGLocalized(@"LightGramSettings.TimeZone") variant:zoneVariant description:TGLocalized(@"LightGramSettings.TimeZoneInfo") pressed:^
    {
        __strong TGLightGramGeneralSettingsController *strongSelf = weakSelf;
        NSMutableArray *offsets = [[NSMutableArray alloc] init];
        NSMutableArray *options = [[NSMutableArray alloc] initWithObjects:TGLocalized(@"LightGramSettings.TimeZoneAutomatic"), nil];
        for (NSInteger minutes = -12 * 60; minutes <= 14 * 60; minutes += 15)
        {
            [offsets addObject:@(minutes)];
            [options addObject:TGLightGramTimeZoneTitle(minutes)];
        }
        NSInteger selected = 0;
        if ([TGLightGramSettings boolForKey:TGLightGramSettingGeneralTimeZoneManual])
        {
            NSUInteger index = [offsets indexOfObject:@([TGLightGramSettings integerForKey:TGLightGramSettingGeneralTimeZoneOffset])];
            selected = index == NSNotFound ? 0 : (NSInteger)index + 1;
        }
        [strongSelf pushChoiceWithTitle:TGLocalized(@"LightGramSettings.TimeZone") options:options selectedIndex:selected footer:TGLocalized(@"LightGramSettings.TimeZoneInfo") completion:^(NSInteger index)
        {
            if (index > 0)
                [TGLightGramSettings setInteger:[offsets[(NSUInteger)index - 1] integerValue] forKey:TGLightGramSettingGeneralTimeZoneOffset];
            [TGLightGramSettings setBool:index > 0 forKey:TGLightGramSettingGeneralTimeZoneManual];
        }];
    }];
    NSMutableArray *generalItems = [[NSMutableArray alloc] init];
    [generalItems addObject:[self switchWithTitle:TGLocalized(@"LightGramSettings.NewChats") key:TGLightGramSettingGeneralNewChats description:TGLocalized(@"LightGramSettings.NewChatsInfo")]];
    if ([TGLightGramSettings boolForKey:TGLightGramSettingGeneralNewChats])
        [generalItems addObject:[self choiceWithTitle:TGLocalized(@"LightGramSettings.MessageMenuStyle") key:TGLightGramSettingGeneralMessageMenuStyle options:@[TGLocalized(@"LightGramSettings.MessageMenuStyleIOS"), TGLocalized(@"LightGramSettings.MessageMenuStyleAndroid")] description:TGLocalized(@"LightGramSettings.MessageMenuStyleInfo")]];
    [generalItems addObjectsFromArray:@[
        [self switchWithTitle:TGLocalized(@"Appearance.NewGestures") value:[[NSUserDefaults standardUserDefaults] boolForKey:@"TGIOS6NewChatListGestures"] toggled:^(bool value)
        {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setBool:value forKey:@"TGIOS6NewChatListGestures"];
            [defaults synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"TGIOS6NewChatListGesturesChanged" object:nil];
        }],
        [self switchWithTitle:TGLocalized(@"LightGramSettings.ShowSeconds") key:TGLightGramSettingGeneralShowSeconds description:TGLocalized(@"LightGramSettings.ShowSecondsInfo")],
        zoneItem,
        [self switchWithTitle:TGLocalized(@"LightGramSettings.ExactNumbers") key:TGLightGramSettingGeneralExactNumbers description:TGLocalized(@"LightGramSettings.ExactNumbersInfo")],
        [self switchWithTitle:TGLocalized(@"LightGramSettings.ExactLastSeen") key:TGLightGramSettingGeneralExactLastSeen description:TGLocalized(@"LightGramSettings.ExactLastSeenInfo")],
        [self switchWithTitle:TGLocalized(@"LightGramSettings.FilterZalgo") key:TGLightGramSettingGeneralFilterZalgo description:TGLocalized(@"LightGramSettings.FilterZalgoInfo")]
    ]];
    [sections addObject:[self sectionWithHeader:TGLocalized(@"LightGramSettings.General") items:generalItems footer:nil]];

    TGMessageMenuPreviewCollectionItem *menuPreview = [[TGMessageMenuPreviewCollectionItem alloc] init];
    menuPreview.menuScale = (CGFloat)[TGLightGramSettings integerForKey:TGLightGramSettingMessagesMenuScale] / 100.0f;
    __weak TGMessageMenuPreviewCollectionItem *weakMenuPreview = menuPreview;
    TGLightGramSliderCollectionItem *menuSize = [self sliderWithTitle:TGLocalized(@"LightGramSettings.MenuSize") key:TGLightGramSettingMessagesMenuScale minimumValue:70 maximumValue:130 formatter:^NSString *(NSInteger value)
    {
        return [NSString stringWithFormat:@"%ld%%", (long)value];
    }];
    menuSize.step = 5;
    menuSize.valueChanged = ^(NSInteger value)
    {
        weakMenuPreview.menuScale = (CGFloat)value / 100.0f;
    };
    [sections addObject:[self sectionWithHeader:TGLocalized(@"LightGramSettings.MessageMenu") items:@[menuPreview, menuSize] footer:TGLocalized(@"LightGramSettings.MenuSizeInfo")]];

    [sections addObject:[self sectionWithHeader:TGLocalized(@"LightGramSettings.Profile") items:@[
        [self switchWithTitle:TGLocalized(@"LightGramSettings.HidePhone") key:TGLightGramSettingGeneralHidePhone description:TGLocalized(@"LightGramSettings.HidePhoneInfo")],
        [self switchWithTitle:TGLocalized(@"LightGramSettings.ShowPeerIds") key:TGLightGramSettingGeneralShowPeerIds description:TGLocalized(@"LightGramSettings.ShowPeerIdsInfo")]
    ] footer:nil]];

    [sections addObject:[self sectionWithHeader:TGLocalized(@"LightGramSettings.Archive") items:@[
        [self switchWithTitle:TGLocalized(@"LightGramSettings.HideArchive") key:TGLightGramSettingGeneralHideArchive description:TGLocalized(@"LightGramSettings.HideArchiveInfo")],
        [self switchWithTitle:TGLocalized(@"LightGramSettings.DisableUnarchiveSwipe") key:TGLightGramSettingGeneralDisableUnarchiveSwipe description:TGLocalized(@"LightGramSettings.DisableUnarchiveSwipeInfo")]
    ] footer:nil]];

    TGSwitchCollectionItem *crashReportsItem = [self switchWithTitle:TGLocalized(@"LightGramSettings.CrashReportsToggle") value:[TGCrashReportCenter reportsEnabled] toggled:^(bool value)
    {
        [TGCrashReportCenter setReportsEnabled:value];
    }];
    crashReportsItem.descriptionText = TGLocalized(@"LightGramSettings.CrashReportsInfo");
    [sections addObject:[self sectionWithHeader:TGLocalized(@"LightGramSettings.CrashReports") items:@[crashReportsItem] footer:nil]];

    return sections;
}

@end

static TGDocumentMediaAttachment *TGLightGramPreviewSticker(void)
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"LightGramPreviewSticker" ofType:@"tgs"];
    if (path.length == 0)
        return nil;
    TGDocumentMediaAttachment *document = [[TGDocumentMediaAttachment alloc] init];
    document.localDocumentId = 0x4f6e6567726d01LL;
    document.mimeType = @"application/x-tgsticker";
    document.documentUri = [[NSURL fileURLWithPath:path] absoluteString];
    document.attributes = @[
        [[TGDocumentAttributeFilename alloc] initWithFilename:@"LightGramPreviewSticker.tgs"],
        [[TGDocumentAttributeImageSize alloc] initWithSize:CGSizeMake(512.0f, 512.0f)],
        [[TGDocumentAttributeSticker alloc] initWithAlt:@"\U0001F44B" packReference:nil mask:nil]
    ];
    return document;
}

static TGMessage *TGLightGramPreviewMessage(int32_t mid, int32_t fromUid, bool outgoing, NSString *text, int32_t minutes)
{
    TGMessage *message = [[TGMessage alloc] init];
    message.mid = mid;
    message.fromUid = fromUid;
    message.outgoing = outgoing;
    message.text = text;
    message.date = 60 * minutes;
    message.deliveryState = TGMessageDeliveryStateDelivered;
    return message;
}

@interface TGLightGramMessagesSettingsController ()
{
    TGAppearancePreviewCollectionItem *_bubblePreviewItem;
    TGAppearancePreviewCollectionItem *_stickerPreviewItem;
    TGDocumentMediaAttachment *_previewSticker;
}

@end

@implementation TGLightGramMessagesSettingsController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGAnimatedEmojiStoreDidUpdateNotification object:nil];
}

- (instancetype)init
{
    self = [super initWithTitle:TGLocalized(@"LightGramSettings.Messages")];
    if (self != nil)
    {
        __weak TGLightGramMessagesSettingsController *weakSelf = self;
        void (^heightChanged)(void) = ^
        {
            __strong TGLightGramMessagesSettingsController *strongSelf = weakSelf;
            [strongSelf.collectionLayout invalidateLayout];
        };

        _bubblePreviewItem = [[TGAppearancePreviewCollectionItem alloc] init];
        _bubblePreviewItem.heightChanged = heightChanged;
        _bubblePreviewItem.messages = [self bubblePreviewMessages];

        _previewSticker = TGLightGramPreviewSticker();
        _stickerPreviewItem = [[TGAppearancePreviewCollectionItem alloc] init];
        _stickerPreviewItem.heightChanged = heightChanged;
        _stickerPreviewItem.messages = [self stickerPreviewMessages];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(animatedEmojiStoreUpdated:) name:TGAnimatedEmojiStoreDidUpdateNotification object:nil];
    }
    return self;
}

- (void)animatedEmojiStoreUpdated:(NSNotification *)__unused notification
{
    if ([TGLightGramSettings boolForKey:TGLightGramSettingMessagesAnimatedEmoji])
        _stickerPreviewItem.messages = [self stickerPreviewMessages];
}

- (NSArray *)bubblePreviewMessages
{
    TGMessage *replyMessage = TGLightGramPreviewMessage(1, 2, false, TGLocalized(@"LightGramSettings.PreviewReply"), 18 * 60 + 19);

    TGReplyMessageMediaAttachment *replyAttachment = [[TGReplyMessageMediaAttachment alloc] init];
    replyAttachment.replyMessageId = replyMessage.mid;
    replyAttachment.replyMessage = replyMessage;

    TGMessage *incomingMessage = TGLightGramPreviewMessage(2, 1, false, TGLocalized(@"LightGramSettings.PreviewIncoming"), 18 * 60 + 20);
    incomingMessage.mediaAttachments = @[replyAttachment];

    TGMessage *outgoingMessage = TGLightGramPreviewMessage(3, 2, true, TGLocalized(@"LightGramSettings.PreviewOutgoing"), 18 * 60 + 21);
    outgoingMessage.isEdited = true;
    outgoingMessage.editDate = outgoingMessage.date + 60;

    return @[outgoingMessage, incomingMessage];
}

- (NSArray *)stickerPreviewMessages
{
    TGMessage *emojiMessage = TGLightGramPreviewMessage(4, 1, false, @"\U0001F44D", 18 * 60 + 21);
    if (_previewSticker == nil)
        return @[emojiMessage];
    TGMessage *stickerMessage = TGLightGramPreviewMessage(5, 2, true, @"", 18 * 60 + 22);
    stickerMessage.mediaAttachments = @[_previewSticker];
    return @[stickerMessage, emojiMessage];
}

- (bool)rebuildsForSettingKey:(NSString *)key
{
    return [key isEqualToString:TGLightGramSettingMessagesDoubleTapIncoming] || [key isEqualToString:TGLightGramSettingMessagesDoubleTapOutgoing] || [key isEqualToString:TGLightGramSettingMessagesQuickReaction];
}

- (void)chooseQuickReaction
{
    TLRPCmessages_getAvailableReactions_manual *request = [[TLRPCmessages_getAvailableReactions_manual alloc] init];
    request.hashValue = 0;
    __weak TGLightGramMessagesSettingsController *weakSelf = self;
    [[[[TGTelegramNetworking instance] requestSignal:request] deliverOn:[SQueue mainQueue]] startWithNext:^(TLmessages_AvailableReactions_manual *result)
    {
        TGLightGramMessagesSettingsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        NSArray *emojis = [result isKindOfClass:[TLmessages_AvailableReactions_manual class]] ? result.activeEmojis : nil;
        if (emojis.count == 0)
        {
            [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"LightGramSettings.ReactionsLoadFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
            return;
        }
        NSString *preferred = [TGLightGramSettings stringForKey:TGLightGramSettingMessagesQuickReaction];
        NSUInteger selected = [emojis indexOfObject:preferred];
        [strongSelf pushChoiceWithTitle:TGLocalized(@"LightGramSettings.QuickReaction") options:emojis selectedIndex:selected == NSNotFound ? -1 : (NSInteger)selected footer:TGLocalized(@"LightGramSettings.QuickReactionInfo") completion:^(NSInteger index)
        {
            if (index < 0 || index >= (NSInteger)emojis.count)
                return;
            NSString *reaction = emojis[(NSUInteger)index];
            TLRPCmessages_setDefaultReaction_manual *setRequest = [[TLRPCmessages_setDefaultReaction_manual alloc] init];
            setRequest.reaction = reaction;
            [[[[TGTelegramNetworking instance] requestSignal:setRequest] deliverOn:[SQueue mainQueue]] startWithNext:^(TLBool *result)
            {
                if ([result boolValue])
                    [TGLightGramSettings setString:reaction forKey:TGLightGramSettingMessagesQuickReaction];
                else
                    [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"LightGramSettings.QuickReactionSaveFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
            } error:^(__unused id error)
            {
                [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"LightGramSettings.QuickReactionSaveFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
            } completed:nil];
        }];
    } error:^(__unused id error)
    {
        if (weakSelf != nil)
            [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"LightGramSettings.ReactionsLoadFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    } completed:nil];
}

- (void)settingDidChange:(NSString *)key
{
    if ([key isEqualToString:TGLightGramSettingMessagesReplyAuthorColor] || [key isEqualToString:TGLightGramSettingMessagesEditedPencil])
        _bubblePreviewItem.messages = [self bubblePreviewMessages];
    else if ([key isEqualToString:TGLightGramSettingMessagesStickerScale])
        _stickerPreviewItem.stickerScale = 0.0f;
    else if ([key isEqualToString:TGLightGramSettingMessagesHideStickerTime] || [key isEqualToString:TGLightGramSettingMessagesAnimatedEmoji] || [key isEqualToString:TGLightGramSettingMessagesAnimatedStickers])
        _stickerPreviewItem.messages = [self stickerPreviewMessages];
}

- (NSArray *)buildSections
{
    __weak TGLightGramMessagesSettingsController *weakSelf = self;

    NSMutableArray *incomingTitles = [[NSMutableArray alloc] init];
    for (NSString *action in TGLightGramDoubleTapActions(false))
        [incomingTitles addObject:TGLightGramDoubleTapTitle(action)];
    NSMutableArray *outgoingTitles = [[NSMutableArray alloc] init];
    for (NSString *action in TGLightGramDoubleTapActions(true))
        [outgoingTitles addObject:TGLightGramDoubleTapTitle(action)];

    NSMutableArray *bubbleItems = [[NSMutableArray alloc] initWithObjects:_bubblePreviewItem, nil];
    if (TGCurrentInterfaceStyle() == 0)
    {
        TGPresentationPallete *pallete = (self.presentation ?: [TGPresentation current]).pallete;
        NSInteger themeRadius = (NSInteger)lroundf((float)[TGPresentationAssets defaultChatBubbleRadius]);
        NSInteger maximumRadius = MAX((NSInteger)15, themeRadius);
        NSInteger storedRadius = [TGLightGramSettings integerForKey:TGLightGramSettingMessagesBubbleRadius];
        TGLightGramSliderCollectionItem *radiusItem = [[TGLightGramSliderCollectionItem alloc] initWithTitle:TGLocalized(@"LightGramSettings.BubbleRadius") minimumValue:0 maximumValue:maximumRadius value:storedRadius < 0 ? themeRadius : MIN(storedRadius, maximumRadius)];
        radiusItem.reversed = true;
        radiusItem.valueFormatter = ^NSString *(NSInteger value)
        {
            return value == themeRadius ? TGLocalized(@"LightGramSettings.Default") : [[NSString alloc] initWithFormat:@"%d", (int)value];
        };
        radiusItem.valueChanged = ^(NSInteger value)
        {
            __strong TGLightGramMessagesSettingsController *strongSelf = weakSelf;
            if (strongSelf != nil)
                strongSelf->_bubblePreviewItem.messagePresentation = [TGPresentation presentationWithPallete:pallete bubbleRadius:value == themeRadius ? -1 : value];
        };
        radiusItem.valueCommitted = ^(NSInteger value)
        {
            [TGLightGramSettings setInteger:value == themeRadius ? -1 : value forKey:TGLightGramSettingMessagesBubbleRadius];
        };
        [bubbleItems addObject:radiusItem];
    }
    [bubbleItems addObject:[self switchWithTitle:TGLocalized(@"LightGramSettings.ReplyAuthorColor") key:TGLightGramSettingMessagesReplyAuthorColor description:TGLocalized(@"LightGramSettings.ReplyAuthorColorInfo")]];
    [bubbleItems addObject:[self switchWithTitle:TGLocalized(@"LightGramSettings.EditedPencil") key:TGLightGramSettingMessagesEditedPencil description:TGLocalized(@"LightGramSettings.EditedPencilInfo")]];

    NSMutableArray *stickerItems = [[NSMutableArray alloc] init];
    [stickerItems addObject:_stickerPreviewItem];
    TGLightGramSliderCollectionItem *stickerItem = [self sliderWithTitle:TGLocalized(@"LightGramSettings.StickerSize") key:TGLightGramSettingMessagesStickerScale minimumValue:50 maximumValue:130 formatter:^NSString *(NSInteger value)
    {
        return [[NSString alloc] initWithFormat:@"%d%%", (int)value];
    }];
    stickerItem.step = 5;
    stickerItem.valueChanged = ^(NSInteger value)
    {
        __strong TGLightGramMessagesSettingsController *strongSelf = weakSelf;
        if (strongSelf != nil)
            strongSelf->_stickerPreviewItem.stickerScale = (CGFloat)value / 100.0f;
    };
    [stickerItems addObject:stickerItem];
    [stickerItems addObject:[self switchWithTitle:TGLocalized(@"LightGramSettings.HideStickerTime") key:TGLightGramSettingMessagesHideStickerTime description:TGLocalized(@"LightGramSettings.HideStickerTimeInfo")]];
    [stickerItems addObject:[self switchWithTitle:TGLocalized(@"LightGramSettings.AnimatedStickers") key:TGLightGramSettingMessagesAnimatedStickers description:TGLocalized(@"LightGramSettings.AnimatedStickersInfo")]];
    [stickerItems addObject:[self switchWithTitle:TGLocalized(@"LightGramSettings.AnimatedEmoji") key:TGLightGramSettingMessagesAnimatedEmoji description:TGLocalized(@"LightGramSettings.AnimatedEmojiInfo")]];

    NSMutableArray *menuItems = [[NSMutableArray alloc] init];
    for (NSString *identifier in TGLightGramMenuActionIdentifiers())
    {
        bool visible = ![[TGLightGramSettings arrayForKey:TGLightGramSettingMessagesMenuHiddenActions] containsObject:identifier];
        [menuItems addObject:[self switchWithTitle:TGLightGramMenuActionTitle(identifier) value:visible toggled:^(bool value)
        {
            NSMutableArray *hidden = [[TGLightGramSettings arrayForKey:TGLightGramSettingMessagesMenuHiddenActions] mutableCopy];
            [hidden removeObject:identifier];
            if (!value)
                [hidden addObject:identifier];
            [TGLightGramSettings setArray:hidden forKey:TGLightGramSettingMessagesMenuHiddenActions];
        }]];
    }

    return @[
        [self sectionWithHeader:TGLocalized(@"LightGramSettings.Bubbles") items:bubbleItems footer:TGLocalized(@"LightGramSettings.BubblesInfo")],
        [self sectionWithHeader:TGLocalized(@"LightGramSettings.Stickers") items:stickerItems footer:TGLocalized(@"LightGramSettings.StickersInfo")],
        [self sectionWithHeader:TGLocalized(@"LightGramSettings.DoubleTap") items:@[
            [self choiceWithTitle:TGLocalized(@"LightGramSettings.DoubleTapIncoming") key:TGLightGramSettingMessagesDoubleTapIncoming options:incomingTitles],
            [self choiceWithTitle:TGLocalized(@"LightGramSettings.DoubleTapOutgoing") key:TGLightGramSettingMessagesDoubleTapOutgoing options:outgoingTitles],
            [self actionWithTitle:TGLocalized(@"LightGramSettings.QuickReaction") variant:[TGLightGramSettings stringForKey:TGLightGramSettingMessagesQuickReaction] description:TGLocalized(@"LightGramSettings.QuickReactionInfo") pressed:^
            {
                [weakSelf chooseQuickReaction];
            }]
        ] footer:TGLocalized(@"LightGramSettings.DoubleTapInfo")],
        [self sectionWithHeader:TGLocalized(@"LightGramSettings.MessageMenu") items:menuItems footer:TGLocalized(@"LightGramSettings.MessageMenuInfo")]
    ];
}

@end

