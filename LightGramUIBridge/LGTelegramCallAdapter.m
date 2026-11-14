#import "LGTelegramCallAdapter.h"
#import "Models/LGCallItem.h"

static LGTelegramCallAdapterMapper LGTelegramCallAdapterCurrentMapper = nil;

@implementation LGTelegramCallAdapter
+ (void)setMapper:(LGTelegramCallAdapterMapper)mapper
{
    @synchronized(self)
    {
        LGTelegramCallAdapterCurrentMapper = [mapper copy];
    }
}

+ (LGCallItem *)itemFromTelegramObject:(id)object
{
    if (object == nil)
        return nil;
    LGTelegramCallAdapterMapper mapper = nil;
    @synchronized(self)
    {
        mapper = LGTelegramCallAdapterCurrentMapper;
    }
    if (mapper == nil)
        return nil;
    return mapper(object);
}
@end
