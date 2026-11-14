#import <Foundation/Foundation.h>
@class LGDialogItem;
typedef LGDialogItem * (^LGTelegramDialogAdapterMapper)(id object);
@interface LGTelegramDialogAdapter : NSObject
+ (void)setMapper:(LGTelegramDialogAdapterMapper)mapper;
+ (LGDialogItem *)itemFromTelegramObject:(id)object;
@end
