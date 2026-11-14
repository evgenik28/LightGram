#import <Foundation/Foundation.h>
@class LGMemberItem;
typedef LGMemberItem * (^LGTelegramGroupAdapterMapper)(id object);
@interface LGTelegramGroupAdapter : NSObject
+ (void)setMapper:(LGTelegramGroupAdapterMapper)mapper;
+ (LGMemberItem *)itemFromTelegramObject:(id)object;
@end
