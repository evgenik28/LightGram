#import <Foundation/Foundation.h>
@class LGMediaItem;
typedef LGMediaItem * (^LGTelegramMediaAdapterMapper)(id object);
@interface LGTelegramMediaAdapter : NSObject
+ (void)setMapper:(LGTelegramMediaAdapterMapper)mapper;
+ (LGMediaItem *)itemFromTelegramObject:(id)object;
@end
