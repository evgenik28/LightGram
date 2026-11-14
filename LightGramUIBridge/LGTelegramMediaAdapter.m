#import "LGTelegramMediaAdapter.h"
#import "Models/LGMediaItem.h"

static LGTelegramMediaAdapterMapper LGTelegramMediaAdapterCurrentMapper = nil;

@implementation LGTelegramMediaAdapter
+ (void)setMapper:(LGTelegramMediaAdapterMapper)mapper
{
    @synchronized(self)
    {
        LGTelegramMediaAdapterCurrentMapper = [mapper copy];
    }
}

+ (LGMediaItem *)itemFromTelegramObject:(id)object
{
    if (object == nil)
        return nil;
    LGTelegramMediaAdapterMapper mapper = nil;
    @synchronized(self)
    {
        mapper = LGTelegramMediaAdapterCurrentMapper;
    }
    if (mapper == nil)
        return nil;
    return mapper(object);
}
@end
