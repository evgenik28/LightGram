#import "LGTelegramDialogAdapter.h"
#import "Models/LGDialogItem.h"

static LGTelegramDialogAdapterMapper LGTelegramDialogAdapterCurrentMapper = nil;

@implementation LGTelegramDialogAdapter
+ (void)setMapper:(LGTelegramDialogAdapterMapper)mapper
{
    @synchronized(self)
    {
        LGTelegramDialogAdapterCurrentMapper = [mapper copy];
    }
}

+ (LGDialogItem *)itemFromTelegramObject:(id)object
{
    if (object == nil)
        return nil;
    LGTelegramDialogAdapterMapper mapper = nil;
    @synchronized(self)
    {
        mapper = LGTelegramDialogAdapterCurrentMapper;
    }
    if (mapper == nil)
        return nil;
    return mapper(object);
}
@end
