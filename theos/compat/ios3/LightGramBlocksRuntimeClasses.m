#import <Foundation/Foundation.h>
#import "Block.h"
#import "Block_private.h"

static void LightGramBlockRetainObject(const void *object)
{
    [(id)object retain];
}

static void LightGramBlockReleaseObject(const void *object)
{
    [(id)object release];
}

__attribute__((constructor)) static void LightGramInitializeBlocksRuntime(void)
{
    _Block_use_RR(LightGramBlockRetainObject, LightGramBlockReleaseObject);
}

@interface LightGramIOS3StackBlock : NSObject <NSCopying>
@end

@implementation LightGramIOS3StackBlock

- (id)copy
{
    return _Block_copy(self);
}

- (id)copyWithZone:(NSZone *)zone
{
    return _Block_copy(self);
}

- (id)retain
{
    return self;
}

- (oneway void)release
{
}

- (NSUInteger)retainCount
{
    return 1;
}

- (id)autorelease
{
    return self;
}

@end

@interface LightGramIOS3MallocBlock : NSObject <NSCopying>
@end

@implementation LightGramIOS3MallocBlock

- (id)copy
{
    return _Block_copy(self);
}

- (id)copyWithZone:(NSZone *)zone
{
    return _Block_copy(self);
}

- (id)retain
{
    return _Block_copy(self);
}

- (oneway void)release
{
    _Block_release(self);
}

- (NSUInteger)retainCount
{
    return 1;
}

- (id)autorelease
{
    return [super autorelease];
}

@end

@interface LightGramIOS3AutoBlock : NSObject <NSCopying>
@end

@implementation LightGramIOS3AutoBlock

- (id)copy
{
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@interface LightGramIOS3FinalizingBlock : LightGramIOS3AutoBlock
@end

@implementation LightGramIOS3FinalizingBlock
@end

@interface LightGramIOS3GlobalBlock : NSObject <NSCopying>
@end

@implementation LightGramIOS3GlobalBlock

- (id)copy
{
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (oneway void)release
{
}

- (NSUInteger)retainCount
{
    return 1;
}

- (id)autorelease
{
    return self;
}

@end

@interface LightGramIOS3BlockVariable : NSObject
@end

@implementation LightGramIOS3BlockVariable
@end

#if !defined(LIGHTGRAM_LINKER_BLOCK_ALIASES)
__asm__(
".globl __NSConcreteStackBlock\n"
".set __NSConcreteStackBlock, _OBJC_CLASS_$_LightGramIOS3StackBlock\n"
".globl __NSConcreteMallocBlock\n"
".set __NSConcreteMallocBlock, _OBJC_CLASS_$_LightGramIOS3MallocBlock\n"
".globl __NSConcreteAutoBlock\n"
".set __NSConcreteAutoBlock, _OBJC_CLASS_$_LightGramIOS3AutoBlock\n"
".globl __NSConcreteFinalizingBlock\n"
".set __NSConcreteFinalizingBlock, _OBJC_CLASS_$_LightGramIOS3FinalizingBlock\n"
".globl __NSConcreteGlobalBlock\n"
".set __NSConcreteGlobalBlock, _OBJC_CLASS_$_LightGramIOS3GlobalBlock\n"
".globl __NSConcreteWeakBlockVariable\n"
".set __NSConcreteWeakBlockVariable, _OBJC_CLASS_$_LightGramIOS3BlockVariable\n"
);
#endif
