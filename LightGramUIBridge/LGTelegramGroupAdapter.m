#import "LGTelegramGroupAdapter.h"
#import "Models/LGMemberItem.h"

static LGTelegramGroupAdapterMapper LGTelegramGroupAdapterCurrentMapper = nil;

@implementation LGTelegramGroupAdapter
+ (void)setMapper:(LGTelegramGroupAdapterMapper)mapper
{
    @synchronized(self)
    {
        LGTelegramGroupAdapterCurrentMapper = [mapper copy];
    }
}

+ (LGMemberItem *)itemFromTelegramObject:(id)object
{
    if (object == nil)
        return nil;
    LGTelegramGroupAdapterMapper mapper = nil;
    @synchronized(self)
    {
        mapper = LGTelegramGroupAdapterCurrentMapper;
    }
    if (mapper == nil)
        return nil;
    return mapper(object);
}
@end
