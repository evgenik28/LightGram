#import "LGTelegramMessageAdapter.h"
#import "Models/LGMessageItem.h"

static LGTelegramMessageAdapterMapper LGTelegramMessageAdapterCurrentMapper = nil;

@implementation LGTelegramMessageAdapter
+ (void)setMapper:(LGTelegramMessageAdapterMapper)mapper
{
    @synchronized(self)
    {
        LGTelegramMessageAdapterCurrentMapper = [mapper copy];
    }
}

+ (LGMessageItem *)itemFromTelegramObject:(id)object
{
    if (object == nil)
        return nil;
    LGTelegramMessageAdapterMapper mapper = nil;
    @synchronized(self)
    {
        mapper = LGTelegramMessageAdapterCurrentMapper;
    }
    if (mapper == nil)
        return nil;
    return mapper(object);
}
@end
