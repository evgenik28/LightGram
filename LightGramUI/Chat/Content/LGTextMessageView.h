#import "../LGMessageContentView.h"
@class LGLabel;
@interface LGTextMessageView : LGMessageContentView
@property (nonatomic, retain, readonly) LGLabel *textLabel;
@property (nonatomic, copy) NSString *text;
@end
