#import <Foundation/Foundation.h>

@class SSignal;

typedef enum {
    TGLightGramTranslatorProviderGoogle = 0,
    TGLightGramTranslatorProviderMicrosoft = 1,
    TGLightGramTranslatorProviderDeepL = 2,
    TGLightGramTranslatorProviderLLM = 3
} TGLightGramTranslatorProvider;

@interface TGLightGramTranslation : NSObject

@property (nonatomic, readonly) NSString *text;
@property (nonatomic, readonly) NSString *sourceLanguage;
@property (nonatomic, readonly) NSString *targetLanguage;

@end

@interface TGLightGramTranslator : NSObject

+ (NSArray *)providerTitles;
+ (NSArray *)languageCodes;
+ (NSString *)displayNameForLanguage:(NSString *)code;
+ (NSString *)targetLanguage;
+ (NSString *)detectedLanguageForText:(NSString *)text;
+ (bool)shouldOfferTranslationForText:(NSString *)text;

+ (SSignal *)translateText:(NSString *)text;

@end
