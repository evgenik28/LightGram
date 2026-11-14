#import <Foundation/Foundation.h>
@class LGCallItem;
typedef LGCallItem * (^LGTelegramCallAdapterMapper)(id object);
@interface LGTelegramCallAdapter : NSObject
+ (void)setMapper:(LGTelegramCallAdapterMapper)mapper;
+ (LGCallItem *)itemFromTelegramObject:(id)object;
@end
