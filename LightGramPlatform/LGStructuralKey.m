#import "LGStructuralKey.h"

NSUInteger LGStructuralKeyHash(id key)
{
    if (![key isKindOfClass:[NSArray class]])
        return [key hash];
    NSArray *components = key;
    NSUInteger hash = components.count;
    for (id component in components)
        hash = hash * 31u + LGStructuralKeyHash(component);
    return hash;
}

static const void *LGStructuralKeyRetain(__unused CFAllocatorRef allocator, const void *value)
{
    return CFRetain(value);
}

static void LGStructuralKeyRelease(__unused CFAllocatorRef allocator, const void *value)
{
    CFRelease(value);
}

static CFHashCode LGStructuralKeyCFHash(const void *value)
{
    return (CFHashCode)LGStructuralKeyHash((__bridge id)value);
}

static const CFDictionaryKeyCallBacks LGStructuralKeyCallBacks = {
    0,
    LGStructuralKeyRetain,
    LGStructuralKeyRelease,
    CFCopyDescription,
    CFEqual,
    LGStructuralKeyCFHash
};

NSMutableDictionary *LGStructuralKeyDictionaryCreate(void)
{
    return (__bridge_transfer NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &LGStructuralKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}
