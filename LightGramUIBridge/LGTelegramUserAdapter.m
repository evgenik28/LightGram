#import "LGTelegramUserAdapter.h"
#import "Models/LGUserItem.h"

static LGTelegramUserAdapterMapper LGTelegramUserAdapterCurrentMapper = nil;

@implementation LGTelegramUserAdapter
+ (void)setMapper:(LGTelegramUserAdapterMapper)mapper
{
    @synchronized(self)
    {
        LGTelegramUserAdapterCurrentMapper = [mapper copy];
    }
}

+ (LGUserItem *)itemFromTelegramObject:(id)object
{
    if (object == nil)
        return nil;
    LGTelegramUserAdapterMapper mapper = nil;
    @synchronized(self)
    {
        mapper = LGTelegramUserAdapterCurrentMapper;
    }
    if (mapper == nil)
        return nil;
    return mapper(object);
}
@end
