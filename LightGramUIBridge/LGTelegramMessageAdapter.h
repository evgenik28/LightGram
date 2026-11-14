#import <Foundation/Foundation.h>
@class LGMessageItem;
typedef LGMessageItem * (^LGTelegramMessageAdapterMapper)(id object);
@interface LGTelegramMessageAdapter : NSObject
+ (void)setMapper:(LGTelegramMessageAdapterMapper)mapper;
+ (LGMessageItem *)itemFromTelegramObject:(id)object;
@end
