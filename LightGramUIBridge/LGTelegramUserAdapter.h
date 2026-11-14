#import <Foundation/Foundation.h>
@class LGUserItem;
typedef LGUserItem * (^LGTelegramUserAdapterMapper)(id object);
@interface LGTelegramUserAdapter : NSObject
+ (void)setMapper:(LGTelegramUserAdapterMapper)mapper;
+ (LGUserItem *)itemFromTelegramObject:(id)object;
@end
