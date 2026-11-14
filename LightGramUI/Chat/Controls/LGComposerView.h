#import "../../Base/LGView.h"
@class LGComposerTextView;
@class LGAttachButton;
@class LGSendButton;
@class LGVoiceButton;
@interface LGComposerView : LGView
@property (nonatomic, retain, readonly) LGComposerTextView *textView;
@property (nonatomic, retain, readonly) LGAttachButton *attachButton;
@property (nonatomic, retain, readonly) LGSendButton *sendButton;
@property (nonatomic, retain, readonly) LGVoiceButton *voiceButton;
@property (nonatomic) BOOL voiceMode;
@end
