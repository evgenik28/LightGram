#import "LightGramIOS3Compatibility.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <math.h>
#include <regex.h>
#include <mach/mach.h>
#include <pthread.h>
#include <dlfcn.h>
#include <libkern/OSAtomic.h>

typedef void (*LightGramIOS3SetAssociatedObjectFunction)(id object, void *key, id value, objc_AssociationPolicy policy);
typedef id (*LightGramIOS3GetAssociatedObjectFunction)(id object, void *key);
typedef void (*LightGramIOS3RemoveAssociatedObjectsFunction)(id object);

enum
{
    LightGramIOS3AssociationFilterSize = 4096
};

typedef struct
{
    id value;
    objc_AssociationPolicy policy;
} LightGramIOS3Association;

static pthread_once_t LightGramIOS3AssociationsOnce = PTHREAD_ONCE_INIT;
static LightGramIOS3SetAssociatedObjectFunction LightGramIOS3NativeSetAssociatedObject = NULL;
static LightGramIOS3GetAssociatedObjectFunction LightGramIOS3NativeGetAssociatedObject = NULL;
static LightGramIOS3RemoveAssociatedObjectsFunction LightGramIOS3NativeRemoveAssociatedObjects = NULL;
static pthread_mutex_t LightGramIOS3AssociationsMutex = PTHREAD_MUTEX_INITIALIZER;
static CFMutableDictionaryRef LightGramIOS3AssociationsByObject = NULL;
static volatile uint32_t LightGramIOS3AssociationFilter[LightGramIOS3AssociationFilterSize];
static IMP LightGramIOS3OriginalNSObjectDealloc = NULL;

static NSUInteger LightGramIOS3AssociationFilterIndex(id object)
{
    uintptr_t address = (uintptr_t)object;
    return (NSUInteger)((address >> 4) ^ (address >> 16)) & (LightGramIOS3AssociationFilterSize - 1);
}

static bool LightGramIOS3AssociationPolicyRetains(objc_AssociationPolicy policy)
{
    return policy != OBJC_ASSOCIATION_ASSIGN;
}

static bool LightGramIOS3AssociationPolicyIsAtomic(objc_AssociationPolicy policy)
{
    return policy == OBJC_ASSOCIATION_RETAIN || policy == OBJC_ASSOCIATION_COPY;
}

static void LightGramIOS3ReleaseAssociations(LightGramIOS3Association *associations, CFIndex count)
{
    for (CFIndex index = 0; index < count; index++)
    {
        if (LightGramIOS3AssociationPolicyRetains(associations[index].policy))
            [associations[index].value release];
    }
}

static void LightGramIOS3FreeAssociationEntry(__unused const void *key, const void *value, void *context)
{
    LightGramIOS3Association *association = (LightGramIOS3Association *)value;
    LightGramIOS3Association **cursor = (LightGramIOS3Association **)context;
    **cursor = *association;
    (*cursor)++;
    free(association);
}

static CFIndex LightGramIOS3DetachAssociationsLocked(id object, LightGramIOS3Association **detached)
{
    *detached = NULL;
    if (LightGramIOS3AssociationsByObject == NULL)
        return 0;
    CFMutableDictionaryRef associations = (CFMutableDictionaryRef)CFDictionaryGetValue(LightGramIOS3AssociationsByObject, object);
    if (associations == NULL)
        return 0;
    CFIndex count = CFDictionaryGetCount(associations);
    if (count != 0)
    {
        *detached = (LightGramIOS3Association *)malloc(sizeof(LightGramIOS3Association) * (size_t)count);
        LightGramIOS3Association *cursor = *detached;
        CFDictionaryApplyFunction(associations, LightGramIOS3FreeAssociationEntry, &cursor);
    }
    CFDictionaryRemoveValue(LightGramIOS3AssociationsByObject, object);
    CFRelease(associations);
    LightGramIOS3AssociationFilter[LightGramIOS3AssociationFilterIndex(object)]--;
    return count;
}

static void LightGramIOS3RemoveFallbackAssociations(id object)
{
    LightGramIOS3Association *detached = NULL;
    pthread_mutex_lock(&LightGramIOS3AssociationsMutex);
    CFIndex count = LightGramIOS3DetachAssociationsLocked(object, &detached);
    pthread_mutex_unlock(&LightGramIOS3AssociationsMutex);
    LightGramIOS3ReleaseAssociations(detached, count);
    free(detached);
}

static void LightGramIOS3NSObjectDealloc(id self, SEL _cmd)
{
    OSMemoryBarrier();
    if (LightGramIOS3AssociationFilter[LightGramIOS3AssociationFilterIndex(self)] != 0)
        LightGramIOS3RemoveFallbackAssociations(self);
    ((void (*)(id, SEL))LightGramIOS3OriginalNSObjectDealloc)(self, _cmd);
}

static void LightGramIOS3InitializeAssociations(void)
{
    LightGramIOS3NativeSetAssociatedObject = (LightGramIOS3SetAssociatedObjectFunction)dlsym(RTLD_NEXT, "objc_setAssociatedObject");
    LightGramIOS3NativeGetAssociatedObject = (LightGramIOS3GetAssociatedObjectFunction)dlsym(RTLD_NEXT, "objc_getAssociatedObject");
    LightGramIOS3NativeRemoveAssociatedObjects = (LightGramIOS3RemoveAssociatedObjectsFunction)dlsym(RTLD_NEXT, "objc_removeAssociatedObjects");
    if (LightGramIOS3NativeSetAssociatedObject != NULL && LightGramIOS3NativeGetAssociatedObject != NULL && LightGramIOS3NativeRemoveAssociatedObjects != NULL)
        return;

    LightGramIOS3NativeSetAssociatedObject = NULL;
    LightGramIOS3NativeGetAssociatedObject = NULL;
    LightGramIOS3NativeRemoveAssociatedObjects = NULL;
    LightGramIOS3AssociationsByObject = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
    Method dealloc = class_getInstanceMethod([NSObject class], @selector(dealloc));
    LightGramIOS3OriginalNSObjectDealloc = method_getImplementation(dealloc);
    method_setImplementation(dealloc, (IMP)LightGramIOS3NSObjectDealloc);
}

void objc_setAssociatedObject(id object, void *key, id value, objc_AssociationPolicy policy)
{
    pthread_once(&LightGramIOS3AssociationsOnce, LightGramIOS3InitializeAssociations);
    if (LightGramIOS3NativeSetAssociatedObject != NULL)
    {
        LightGramIOS3NativeSetAssociatedObject(object, key, value, policy);
        return;
    }
    if (object == nil)
        return;

    id storedValue = value;
    if (value != nil && (policy == OBJC_ASSOCIATION_COPY || policy == OBJC_ASSOCIATION_COPY_NONATOMIC))
        storedValue = [value copy];
    else if (value != nil && LightGramIOS3AssociationPolicyRetains(policy))
        storedValue = [value retain];

    LightGramIOS3Association previous = { nil, OBJC_ASSOCIATION_ASSIGN };
    pthread_mutex_lock(&LightGramIOS3AssociationsMutex);
    CFMutableDictionaryRef associations = (CFMutableDictionaryRef)CFDictionaryGetValue(LightGramIOS3AssociationsByObject, object);
    LightGramIOS3Association *association = associations == NULL ? NULL : (LightGramIOS3Association *)CFDictionaryGetValue(associations, key);
    if (association != NULL)
        previous = *association;
    if (storedValue != nil)
    {
        if (associations == NULL)
        {
            associations = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
            CFDictionarySetValue(LightGramIOS3AssociationsByObject, object, associations);
            LightGramIOS3AssociationFilter[LightGramIOS3AssociationFilterIndex(object)]++;
        }
        if (association == NULL)
        {
            association = (LightGramIOS3Association *)malloc(sizeof(LightGramIOS3Association));
            CFDictionarySetValue(associations, key, association);
        }
        association->value = storedValue;
        association->policy = policy;
    }
    else if (association != NULL)
    {
        CFDictionaryRemoveValue(associations, key);
        free(association);
        if (CFDictionaryGetCount(associations) == 0)
        {
            CFDictionaryRemoveValue(LightGramIOS3AssociationsByObject, object);
            CFRelease(associations);
            LightGramIOS3AssociationFilter[LightGramIOS3AssociationFilterIndex(object)]--;
        }
    }
    pthread_mutex_unlock(&LightGramIOS3AssociationsMutex);
    LightGramIOS3ReleaseAssociations(&previous, previous.value == nil ? 0 : 1);
}

id objc_getAssociatedObject(id object, void *key)
{
    pthread_once(&LightGramIOS3AssociationsOnce, LightGramIOS3InitializeAssociations);
    if (LightGramIOS3NativeGetAssociatedObject != NULL)
        return LightGramIOS3NativeGetAssociatedObject(object, key);
    if (object == nil)
        return nil;

    id value = nil;
    pthread_mutex_lock(&LightGramIOS3AssociationsMutex);
    CFMutableDictionaryRef associations = (CFMutableDictionaryRef)CFDictionaryGetValue(LightGramIOS3AssociationsByObject, object);
    LightGramIOS3Association *association = associations == NULL ? NULL : (LightGramIOS3Association *)CFDictionaryGetValue(associations, key);
    if (association != NULL)
    {
        value = association->value;
        if (LightGramIOS3AssociationPolicyIsAtomic(association->policy))
            [[value retain] autorelease];
    }
    pthread_mutex_unlock(&LightGramIOS3AssociationsMutex);
    return value;
}

void objc_removeAssociatedObjects(id object)
{
    pthread_once(&LightGramIOS3AssociationsOnce, LightGramIOS3InitializeAssociations);
    if (LightGramIOS3NativeRemoveAssociatedObjects != NULL)
    {
        LightGramIOS3NativeRemoveAssociatedObjects(object);
        return;
    }
    if (object != nil)
        LightGramIOS3RemoveFallbackAssociations(object);
}

static void LightGramIOS3InstallFallbackMethodsIntoClass(Class targetClass)
{
    static const char prefix[] = "lightgramIOS3Fallback_";
    size_t prefixLength = sizeof(prefix) - 1;
    unsigned int count = 0;
    Method *methods = class_copyMethodList(targetClass, &count);
    for (unsigned int index = 0; index < count; index++)
    {
        const char *name = sel_getName(method_getName(methods[index]));
        if (strncmp(name, prefix, prefixLength) != 0)
            continue;
        SEL selector = sel_registerName(name + prefixLength);
        if (class_getInstanceMethod(targetClass, selector) != NULL)
            continue;
        class_addMethod(targetClass, selector, method_getImplementation(methods[index]), method_getTypeEncoding(methods[index]));
    }
    free(methods);
}

static void LightGramIOS3InstallFallbackMethods(Class targetClass)
{
    LightGramIOS3InstallFallbackMethodsIntoClass(targetClass);
    LightGramIOS3InstallFallbackMethodsIntoClass(object_getClass(targetClass));
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000

static char LightGramIOS3WindowRootViewControllerKey;
static char LightGramIOS3OperationThreadPriorityKey;
static UIApplicationState LightGramIOS3ApplicationState = UIApplicationStateInactive;

@implementation UIWindow (LightGramIOS3RootViewControllerCompatibilityFallback)

- (UIViewController *)lightgramIOS3Fallback_rootViewController
{
    return objc_getAssociatedObject(self, &LightGramIOS3WindowRootViewControllerKey);
}

- (void)lightgramIOS3Fallback_setRootViewController:(UIViewController *)rootViewController
{
    UIViewController *currentController = objc_getAssociatedObject(self, &LightGramIOS3WindowRootViewControllerKey);
    if (currentController == rootViewController)
        return;

    if (currentController != nil && currentController.view.superview == self)
        [currentController.view removeFromSuperview];

    objc_setAssociatedObject(self, &LightGramIOS3WindowRootViewControllerKey, rootViewController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (rootViewController != nil)
    {
        UIView *view = rootViewController.view;
        view.frame = self.bounds;
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:view];
    }
}

@end

@implementation UIViewController (LightGramIOS3LayoutLifecycleCompatibilityFallback)

- (void)lightgramIOS3Fallback_viewWillLayoutSubviews
{
}

- (void)lightgramIOS3Fallback_viewDidLayoutSubviews
{
}

@end

@interface LightGramIOS3BarButtonItemsToolbar : UIToolbar
@end

@implementation LightGramIOS3BarButtonItemsToolbar

- (void)drawRect:(CGRect)rect
{
}

@end

static CGFloat LightGramIOS3BarButtonItemWidth(UIBarButtonItem *item)
{
    if (item.customView != nil)
    {
        CGSize size = item.customView.bounds.size;
        if (size.width < 1.0f)
            size = [item.customView sizeThatFits:CGSizeMake(160.0f, 44.0f)];
        if (size.width > 0.0f)
            return size.width;
    }

    if (item.width > 0.0f)
        return item.width;

    if (item.title.length != 0)
    {
        CGSize size = [item.title sizeWithFont:[UIFont boldSystemFontOfSize:12.0f]];
        return MAX(30.0f, size.width + 20.0f);
    }

    if (item.image != nil)
        return MAX(30.0f, item.image.size.width + 20.0f);

    return 32.0f;
}

static UIBarButtonItem *LightGramIOS3CombinedRightBarButtonItem(NSArray *items)
{
    NSUInteger count = items.count;
    if (count == 0)
        return nil;
    if (count == 1)
        return [items objectAtIndex:0];

    NSMutableArray *toolbarItems = [[NSMutableArray alloc] initWithCapacity:count];
    CGFloat width = 0.0f;
    for (NSInteger index = (NSInteger)count - 1; index >= 0; index--)
    {
        UIBarButtonItem *item = [items objectAtIndex:(NSUInteger)index];
        [toolbarItems addObject:item];
        width += LightGramIOS3BarButtonItemWidth(item);
    }
    width += (count - 1) * 4.0f;

    LightGramIOS3BarButtonItemsToolbar *toolbar = [[LightGramIOS3BarButtonItemsToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, width, 44.0f)];
    toolbar.opaque = NO;
    toolbar.backgroundColor = [UIColor clearColor];
    [toolbar setItems:toolbarItems animated:NO];
    [toolbarItems release];

    UIBarButtonItem *result = [[[UIBarButtonItem alloc] initWithCustomView:toolbar] autorelease];
    [toolbar release];
    return result;
}

@implementation UINavigationItem (LightGramIOS3ModernBarButtonCompatibilityFallback)

- (void)lightgramIOS3Fallback_setRightBarButtonItems:(NSArray *)items animated:(BOOL)animated
{
    [self setRightBarButtonItem:LightGramIOS3CombinedRightBarButtonItem(items) animated:animated];
}

@end

@implementation UIApplication (LightGramIOS3ApplicationStateCompatibilityFallback)

+ (void)load
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(lightgramIOS3DidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(lightgramIOS3WillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
}

+ (void)lightgramIOS3DidBecomeActive:(NSNotification *)notification
{
    LightGramIOS3ApplicationState = UIApplicationStateActive;
}

+ (void)lightgramIOS3WillResignActive:(NSNotification *)notification
{
    LightGramIOS3ApplicationState = UIApplicationStateInactive;
}

- (UIApplicationState)lightgramIOS3Fallback_applicationState
{
    return LightGramIOS3ApplicationState;
}

@end

@interface LightGramIOS3MainOperationQueue : NSOperationQueue
@end

@implementation LightGramIOS3MainOperationQueue

- (void)addOperation:(NSOperation *)operation
{
    if (operation == nil)
        return;
    if ([NSThread isMainThread])
        [operation start];
    else
        [operation performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
}

- (void)addOperations:(NSArray *)operations waitUntilFinished:(BOOL)wait
{
    for (NSOperation *operation in operations)
    {
        if (operation == nil)
            continue;
        if ([NSThread isMainThread])
            [operation start];
        else
            [operation performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:wait];
    }
}

@end

@implementation NSOperationQueue (LightGramIOS3MainQueueCompatibilityFallback)

+ (NSOperationQueue *)lightgramIOS3Fallback_mainQueue
{
    static LightGramIOS3MainOperationQueue *queue = nil;
    @synchronized(self)
    {
        if (queue == nil)
            queue = [[LightGramIOS3MainOperationQueue alloc] init];
    }
    return queue;
}

@end

@implementation NSOperation (LightGramIOS3ThreadPriorityCompatibilityFallback)

- (double)lightgramIOS3Fallback_threadPriority
{
    NSNumber *value = objc_getAssociatedObject(self, &LightGramIOS3OperationThreadPriorityKey);
    return value == nil ? 0.5 : [value doubleValue];
}

- (void)lightgramIOS3Fallback_setThreadPriority:(double)threadPriority
{
    double value = MIN(1.0, MAX(0.0, threadPriority));
    objc_setAssociatedObject(self, &LightGramIOS3OperationThreadPriorityKey, [NSNumber numberWithDouble:value], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation NSBlockOperation

+ (instancetype)blockOperationWithBlock:(void (^)(void))block
{
    NSBlockOperation *operation = [[[self alloc] init] autorelease];
    [operation addExecutionBlock:block];
    return operation;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
        _lightgramExecutionBlocks = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc
{
    [_lightgramExecutionBlocks release];
    [super dealloc];
}

- (void)addExecutionBlock:(void (^)(void))block
{
    if (block == nil)
        return;
    id copiedBlock = [block copy];
    @synchronized(self)
    {
        if (!_lightgramStarted && ![self isExecuting] && ![self isFinished])
            [_lightgramExecutionBlocks addObject:copiedBlock];
    }
    [copiedBlock release];
}

- (void)start
{
    @synchronized(self)
    {
        if (_lightgramStarted || [self isExecuting] || [self isFinished])
            return;
        _lightgramStarted = YES;
    }
    [super start];
}

- (NSArray *)executionBlocks
{
    @synchronized(self)
    {
        return [[_lightgramExecutionBlocks copy] autorelease];
    }
}

- (void)main
{
    double previousPriority = [NSThread threadPriority];
    [NSThread setThreadPriority:self.threadPriority];
    NSArray *blocks = [self executionBlocks];
    for (id value in blocks)
    {
        if ([self isCancelled])
            break;
        void (^block)(void) = value;
        block();
    }
    [NSThread setThreadPriority:previousPriority];
}

@end

@interface LightGramIOS3URLConnectionDelivery : NSObject
{
    void (^_lightgramHandler)(NSURLResponse *, NSData *, NSError *);
    NSURLResponse *_lightgramResponse;
    NSData *_lightgramData;
    NSError *_lightgramError;
}
- (instancetype)initWithHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error;
- (void)invoke;
@end

@implementation LightGramIOS3URLConnectionDelivery

- (instancetype)initWithHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error
{
    self = [super init];
    if (self != nil)
    {
        _lightgramHandler = [handler copy];
        _lightgramResponse = [response retain];
        _lightgramData = [data retain];
        _lightgramError = [error retain];
    }
    return self;
}

- (void)dealloc
{
    [_lightgramHandler release];
    [_lightgramResponse release];
    [_lightgramData release];
    [_lightgramError release];
    [super dealloc];
}

- (void)invoke
{
    if (_lightgramHandler != nil)
        _lightgramHandler(_lightgramResponse, _lightgramData, _lightgramError);
}

@end

@interface LightGramIOS3URLConnectionRequest : NSObject
{
    NSURLRequest *_lightgramRequest;
    NSOperationQueue *_lightgramQueue;
    void (^_lightgramHandler)(NSURLResponse *, NSData *, NSError *);
}
- (instancetype)initWithRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue handler:(void (^)(NSURLResponse *, NSData *, NSError *))handler;
- (void)startAndRelease;
@end

@implementation LightGramIOS3URLConnectionRequest

- (instancetype)initWithRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue handler:(void (^)(NSURLResponse *, NSData *, NSError *))handler
{
    self = [super init];
    if (self != nil)
    {
        _lightgramRequest = [request copy];
        _lightgramQueue = [queue retain];
        _lightgramHandler = [handler copy];
    }
    return self;
}

- (void)dealloc
{
    [_lightgramRequest release];
    [_lightgramQueue release];
    [_lightgramHandler release];
    [super dealloc];
}

- (void)startAndRelease
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:_lightgramRequest returningResponse:&response error:&error];
    if (_lightgramHandler != nil)
    {
        LightGramIOS3URLConnectionDelivery *delivery = [[LightGramIOS3URLConnectionDelivery alloc] initWithHandler:_lightgramHandler response:response data:data error:error];
        if (_lightgramQueue != nil)
        {
            NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:delivery selector:@selector(invoke) object:nil];
            [_lightgramQueue addOperation:operation];
            [operation release];
        }
        else
            [delivery invoke];
        [delivery release];
    }
    [self release];
    [pool drain];
}

@end

@implementation NSURLConnection (LightGramIOS3AsyncCompatibilityFallback)

+ (void)lightgramIOS3Fallback_sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler
{
    if (request == nil)
        return;
    LightGramIOS3URLConnectionRequest *operation = [[LightGramIOS3URLConnectionRequest alloc] initWithRequest:request queue:queue handler:handler];
    [NSThread detachNewThreadSelector:@selector(startAndRelease) toTarget:operation withObject:nil];
}

@end

@implementation NSUUID

+ (NSUUID *)UUID
{
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef string = CFUUIDCreateString(kCFAllocatorDefault, uuid);
    NSUUID *result = [[[self alloc] initWithUUIDString:(NSString *)string] autorelease];
    if (string != NULL)
        CFRelease(string);
    if (uuid != NULL)
        CFRelease(uuid);
    return result;
}

- (instancetype)initWithUUIDString:(NSString *)string
{
    self = [super init];
    if (self != nil)
    {
        if (string == nil)
        {
            [self release];
            return nil;
        }
        CFUUIDRef uuid = CFUUIDCreateFromString(kCFAllocatorDefault, (CFStringRef)string);
        if (uuid == NULL)
        {
            [self release];
            return nil;
        }
        CFStringRef normalized = CFUUIDCreateString(kCFAllocatorDefault, uuid);
        _lightgramUUIDString = [(NSString *)normalized copy];
        if (normalized != NULL)
            CFRelease(normalized);
        CFRelease(uuid);
    }
    return self;
}

- (void)dealloc
{
    [_lightgramUUIDString release];
    [super dealloc];
}

- (NSString *)UUIDString
{
    return _lightgramUUIDString;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (NSUInteger)hash
{
    return [_lightgramUUIDString hash];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSUUID class]])
        return NO;
    return [_lightgramUUIDString isEqualToString:[object UUIDString]];
}

- (NSString *)description
{
    return _lightgramUUIDString;
}

@end

@interface LightGramIOS3NotificationDelivery : NSObject
{
    void (^_block)(NSNotification *);
    NSNotification *_notification;
}
- (instancetype)initWithBlock:(void (^)(NSNotification *))block notification:(NSNotification *)notification;
- (void)invoke;
@end

@implementation LightGramIOS3NotificationDelivery

- (instancetype)initWithBlock:(void (^)(NSNotification *))block notification:(NSNotification *)notification
{
    self = [super init];
    if (self != nil)
    {
        _block = [block copy];
        _notification = [notification retain];
    }
    return self;
}

- (void)dealloc
{
    [_block release];
    [_notification release];
    [super dealloc];
}

- (void)invoke
{
    if (_block != nil)
        _block(_notification);
}

@end

@interface LightGramIOS3NotificationBlockObserver : NSObject
{
    NSNotificationCenter *_center;
    NSOperationQueue *_queue;
    void (^_block)(NSNotification *);
}
- (instancetype)initWithCenter:(NSNotificationCenter *)center name:(NSString *)name object:(id)object queue:(NSOperationQueue *)queue block:(void (^)(NSNotification *))block;
- (void)invalidate;
@end

@implementation LightGramIOS3NotificationBlockObserver

- (instancetype)initWithCenter:(NSNotificationCenter *)center name:(NSString *)name object:(id)object queue:(NSOperationQueue *)queue block:(void (^)(NSNotification *))block
{
    self = [super init];
    if (self != nil)
    {
        _center = center;
        _queue = [queue retain];
        _block = [block copy];
        [_center addObserver:self selector:@selector(receiveNotification:) name:name object:object];
    }
    return self;
}

- (void)dealloc
{
    [_queue release];
    [_block release];
    [super dealloc];
}

- (void)receiveNotification:(NSNotification *)notification
{
    if (_block == nil)
        return;

    if (_queue == nil)
    {
        void (^block)(NSNotification *) = [_block copy];
        if (block != nil)
            block(notification);
        [block release];
    }
    else
    {
        LightGramIOS3NotificationDelivery *delivery = [[LightGramIOS3NotificationDelivery alloc] initWithBlock:_block notification:notification];
        NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:delivery selector:@selector(invoke) object:nil];
        [_queue addOperation:operation];
        [operation release];
        [delivery release];
    }
}

- (void)invalidate
{
    _center = nil;
    [_queue release];
    _queue = nil;
    [_block release];
    _block = nil;
}

@end

static char LightGramIOS3NotificationBlockObserversKey;
static void (*LightGramIOS3OriginalRemoveObserver)(id, SEL, id) = NULL;
static void (*LightGramIOS3OriginalRemoveObserverNameObject)(id, SEL, id, NSString *, id) = NULL;

static void LightGramIOS3StoreNotificationBlockObserver(NSNotificationCenter *center, LightGramIOS3NotificationBlockObserver *observer)
{
    @synchronized(center)
    {
        NSMutableArray *observers = objc_getAssociatedObject(center, &LightGramIOS3NotificationBlockObserversKey);
        if (observers == nil)
        {
            observers = [NSMutableArray array];
            objc_setAssociatedObject(center, &LightGramIOS3NotificationBlockObserversKey, observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [observers addObject:observer];
    }
}

static void LightGramIOS3ForgetNotificationBlockObserver(NSNotificationCenter *center, LightGramIOS3NotificationBlockObserver *observer)
{
    @synchronized(center)
    {
        NSMutableArray *observers = objc_getAssociatedObject(center, &LightGramIOS3NotificationBlockObserversKey);
        [observers removeObjectIdenticalTo:observer];
        if ([observers count] == 0)
            objc_setAssociatedObject(center, &LightGramIOS3NotificationBlockObserversKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static id LightGramIOS3AddNotificationBlockObserver(NSNotificationCenter *center, SEL __unused selector, NSString *name, id object, NSOperationQueue *queue, void (^block)(NSNotification *))
{
    if (block == nil)
        return nil;

    LightGramIOS3NotificationBlockObserver *observer = [[[LightGramIOS3NotificationBlockObserver alloc] initWithCenter:center name:name object:object queue:queue block:block] autorelease];
    LightGramIOS3StoreNotificationBlockObserver(center, observer);
    return observer;
}

static void LightGramIOS3RemoveNotificationObserver(NSNotificationCenter *center, SEL selector, id observer)
{
    LightGramIOS3NotificationBlockObserver *blockObserver = [observer isKindOfClass:[LightGramIOS3NotificationBlockObserver class]] ? [observer retain] : nil;
    if (LightGramIOS3OriginalRemoveObserver != NULL)
        LightGramIOS3OriginalRemoveObserver(center, selector, observer);
    if (blockObserver != nil)
    {
        [blockObserver invalidate];
        LightGramIOS3ForgetNotificationBlockObserver(center, blockObserver);
        [blockObserver release];
    }
}

static void LightGramIOS3RemoveNotificationObserverNameObject(NSNotificationCenter *center, SEL selector, id observer, NSString *name, id object)
{
    LightGramIOS3NotificationBlockObserver *blockObserver = [observer isKindOfClass:[LightGramIOS3NotificationBlockObserver class]] ? [observer retain] : nil;
    if (LightGramIOS3OriginalRemoveObserverNameObject != NULL)
        LightGramIOS3OriginalRemoveObserverNameObject(center, selector, observer, name, object);
    if (blockObserver != nil)
    {
        [blockObserver invalidate];
        LightGramIOS3ForgetNotificationBlockObserver(center, blockObserver);
        [blockObserver release];
    }
}

@interface LightGramIOS3NotificationCenterCompatibilityInstaller : NSObject
@end

@implementation LightGramIOS3NotificationCenterCompatibilityInstaller

+ (void)load
{
    Class notificationCenterClass = [NSNotificationCenter class];
    SEL blockObserverSelector = @selector(addObserverForName:object:queue:usingBlock:);
    if ([notificationCenterClass instancesRespondToSelector:blockObserverSelector])
        return;

    class_addMethod(notificationCenterClass, blockObserverSelector, (IMP)LightGramIOS3AddNotificationBlockObserver, "@@:@@@@");

    Method removeObserverMethod = class_getInstanceMethod(notificationCenterClass, @selector(removeObserver:));
    if (removeObserverMethod != NULL)
    {
        LightGramIOS3OriginalRemoveObserver = (void (*)(id, SEL, id))method_getImplementation(removeObserverMethod);
        class_replaceMethod(notificationCenterClass, @selector(removeObserver:), (IMP)LightGramIOS3RemoveNotificationObserver, method_getTypeEncoding(removeObserverMethod));
    }

    Method removeObserverNameObjectMethod = class_getInstanceMethod(notificationCenterClass, @selector(removeObserver:name:object:));
    if (removeObserverNameObjectMethod != NULL)
    {
        LightGramIOS3OriginalRemoveObserverNameObject = (void (*)(id, SEL, id, NSString *, id))method_getImplementation(removeObserverNameObjectMethod);
        class_replaceMethod(notificationCenterClass, @selector(removeObserver:name:object:), (IMP)LightGramIOS3RemoveNotificationObserverNameObject, method_getTypeEncoding(removeObserverNameObjectMethod));
    }
}

@end

typedef struct
{
    void (^block)(void);
    CFRunLoopSourceRef source;
} LightGramIOS3RunLoopBlockContext;

static void LightGramIOS3RunLoopBlockRelease(const void *info)
{
    LightGramIOS3RunLoopBlockContext *context = (LightGramIOS3RunLoopBlockContext *)info;
    [(id)context->block release];
    free(context);
}

static void LightGramIOS3RunLoopBlockPerform(void *info)
{
    LightGramIOS3RunLoopBlockContext *context = (LightGramIOS3RunLoopBlockContext *)info;
    if (context->block != nil)
        context->block();
    if (context->source != NULL)
        CFRunLoopSourceInvalidate(context->source);
}

void CFRunLoopPerformBlock(CFRunLoopRef runLoop, CFTypeRef mode, void (^block)(void))
{
    if (runLoop == NULL || mode == NULL || block == nil)
        return;

    LightGramIOS3RunLoopBlockContext *context = calloc(1, sizeof(LightGramIOS3RunLoopBlockContext));
    context->block = [block copy];

    CFRunLoopSourceContext sourceContext = {0};
    sourceContext.info = context;
    sourceContext.release = LightGramIOS3RunLoopBlockRelease;
    sourceContext.perform = LightGramIOS3RunLoopBlockPerform;

    CFRunLoopSourceRef source = CFRunLoopSourceCreate(NULL, 0, &sourceContext);
    if (source == NULL)
    {
        [(id)context->block release];
        free(context);
        return;
    }

    context->source = source;
    CFRunLoopAddSource(runLoop, source, mode);
    CFRunLoopSourceSignal(source);
    CFRunLoopWakeUp(runLoop);
    CFRelease(source);
}

extern mach_port_t _dispatch_get_main_queue_port_4CF(void);
extern void _dispatch_main_queue_callback_4CF(mach_msg_header_t *message);

static CFMachPortRef LightGramIOS3DispatchMainQueuePort = NULL;

static void LightGramIOS3DispatchMainQueuePortCallback(CFMachPortRef port, void *message, CFIndex size, void *info)
{
    (void)port;
    (void)size;
    (void)info;
    _dispatch_main_queue_callback_4CF((mach_msg_header_t *)message);
}

@interface LightGramIOS3DispatchMainQueueInstaller : NSObject
@end

@implementation LightGramIOS3DispatchMainQueueInstaller

+ (void)load
{
    if (LightGramIOS3DispatchMainQueuePort != NULL)
        return;

    mach_port_t port = _dispatch_get_main_queue_port_4CF();
    if (port == MACH_PORT_NULL)
        return;

    CFMachPortContext context = {0, NULL, NULL, NULL, NULL};
    CFMachPortRef machPort = CFMachPortCreateWithPort(kCFAllocatorDefault, port, LightGramIOS3DispatchMainQueuePortCallback, &context, NULL);
    if (machPort == NULL)
        return;

    CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0);
    if (source == NULL)
    {
        CFRelease(machPort);
        return;
    }

    LightGramIOS3DispatchMainQueuePort = machPort;
    CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
    CFRelease(source);
}

@end

@implementation CLPlacemark

- (instancetype)initWithLocation:(CLLocation *)location addressDictionary:(NSDictionary *)addressDictionary
{
    self = [super init];
    if (self != nil)
    {
        _location = [location retain];
        _addressDictionary = [addressDictionary copy];
    }
    return self;
}

- (void)dealloc
{
    [_location release];
    [_addressDictionary release];
    [super dealloc];
}

- (CLLocation *)location
{
    return _location;
}

- (NSDictionary *)addressDictionary
{
    return _addressDictionary;
}

- (NSString *)locality
{
    return [_addressDictionary objectForKey:@"City"];
}

@end

static void LightGramIOS3RoundedRectPath(CGMutablePathRef path, CGRect rect, UIRectCorner corners, CGSize radii)
{
    CGFloat rx = MIN(fabs(radii.width), fabs(rect.size.width) * 0.5f);
    CGFloat ry = MIN(fabs(radii.height), fabs(rect.size.height) * 0.5f);
    CGFloat k = 0.5522847498307936f;
    CGFloat minX = CGRectGetMinX(rect);
    CGFloat maxX = CGRectGetMaxX(rect);
    CGFloat minY = CGRectGetMinY(rect);
    CGFloat maxY = CGRectGetMaxY(rect);

    CGPathMoveToPoint(path, NULL, minX + ((corners & UIRectCornerTopLeft) ? rx : 0.0f), minY);

    if (corners & UIRectCornerTopRight)
    {
        CGPathAddLineToPoint(path, NULL, maxX - rx, minY);
        CGPathAddCurveToPoint(path, NULL, maxX - rx + rx * k, minY, maxX, minY + ry - ry * k, maxX, minY + ry);
    }
    else
        CGPathAddLineToPoint(path, NULL, maxX, minY);

    if (corners & UIRectCornerBottomRight)
    {
        CGPathAddLineToPoint(path, NULL, maxX, maxY - ry);
        CGPathAddCurveToPoint(path, NULL, maxX, maxY - ry + ry * k, maxX - rx + rx * k, maxY, maxX - rx, maxY);
    }
    else
        CGPathAddLineToPoint(path, NULL, maxX, maxY);

    if (corners & UIRectCornerBottomLeft)
    {
        CGPathAddLineToPoint(path, NULL, minX + rx, maxY);
        CGPathAddCurveToPoint(path, NULL, minX + rx - rx * k, maxY, minX, maxY - ry + ry * k, minX, maxY - ry);
    }
    else
        CGPathAddLineToPoint(path, NULL, minX, maxY);

    if (corners & UIRectCornerTopLeft)
    {
        CGPathAddLineToPoint(path, NULL, minX, minY + ry);
        CGPathAddCurveToPoint(path, NULL, minX, minY + ry - ry * k, minX + rx - rx * k, minY, minX + rx, minY);
    }
    else
        CGPathAddLineToPoint(path, NULL, minX, minY);

    CGPathCloseSubpath(path);
}

@implementation UIBezierPath

+ (UIBezierPath *)bezierPath
{
    return [[[self alloc] init] autorelease];
}

+ (UIBezierPath *)bezierPathWithRect:(CGRect)rect
{
    UIBezierPath *path = [self bezierPath];
    CGPathAddRect(path->_lightgramPath, NULL, rect);
    return path;
}

+ (UIBezierPath *)bezierPathWithOvalInRect:(CGRect)rect
{
    UIBezierPath *path = [self bezierPath];
    CGPathAddEllipseInRect(path->_lightgramPath, NULL, rect);
    return path;
}

+ (UIBezierPath *)bezierPathWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius
{
    return [self bezierPathWithRoundedRect:rect byRoundingCorners:UIRectCornerAllCorners cornerRadii:CGSizeMake(cornerRadius, cornerRadius)];
}

+ (UIBezierPath *)bezierPathWithRoundedRect:(CGRect)rect byRoundingCorners:(UIRectCorner)corners cornerRadii:(CGSize)cornerRadii
{
    UIBezierPath *path = [self bezierPath];
    LightGramIOS3RoundedRectPath(path->_lightgramPath, rect, corners, cornerRadii);
    return path;
}

+ (UIBezierPath *)bezierPathWithArcCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise
{
    UIBezierPath *path = [self bezierPath];
    CGPathAddArc(path->_lightgramPath, NULL, center.x, center.y, radius, startAngle, endAngle, clockwise);
    return path;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _lightgramPath = CGPathCreateMutable();
        _lightgramLineWidth = 1.0f;
        _lightgramLineCapStyle = kCGLineCapButt;
        _lightgramLineJoinStyle = kCGLineJoinMiter;
    }
    return self;
}

- (void)dealloc
{
    if (_lightgramPath != NULL)
        CGPathRelease(_lightgramPath);
    [super dealloc];
}

- (CGPathRef)CGPath { return _lightgramPath; }
- (CGFloat)lineWidth { return _lightgramLineWidth; }
- (void)setLineWidth:(CGFloat)value { _lightgramLineWidth = value; }
- (CGLineCap)lineCapStyle { return _lightgramLineCapStyle; }
- (void)setLineCapStyle:(CGLineCap)value { _lightgramLineCapStyle = value; }
- (CGLineJoin)lineJoinStyle { return _lightgramLineJoinStyle; }
- (void)setLineJoinStyle:(CGLineJoin)value { _lightgramLineJoinStyle = value; }
- (BOOL)usesEvenOddFillRule { return _lightgramUsesEvenOddFillRule; }
- (void)setUsesEvenOddFillRule:(BOOL)value { _lightgramUsesEvenOddFillRule = value; }

- (void)moveToPoint:(CGPoint)point
{
    CGPathMoveToPoint(_lightgramPath, NULL, point.x, point.y);
}

- (void)addLineToPoint:(CGPoint)point
{
    CGPathAddLineToPoint(_lightgramPath, NULL, point.x, point.y);
}

- (void)addArcWithCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise
{
    CGPathAddArc(_lightgramPath, NULL, center.x, center.y, radius, startAngle, endAngle, clockwise);
}

- (void)closePath
{
    CGPathCloseSubpath(_lightgramPath);
}

- (void)appendPath:(UIBezierPath *)bezierPath
{
    if (bezierPath != nil)
        CGPathAddPath(_lightgramPath, NULL, bezierPath.CGPath);
}

- (void)fill
{
    [self fillWithBlendMode:kCGBlendModeNormal alpha:1.0f];
}

- (void)fillWithBlendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL)
        return;
    CGContextSaveGState(context);
    CGContextSetBlendMode(context, blendMode);
    CGContextSetAlpha(context, alpha);
    CGContextAddPath(context, _lightgramPath);
    CGContextDrawPath(context, _lightgramUsesEvenOddFillRule ? kCGPathEOFill : kCGPathFill);
    CGContextRestoreGState(context);
}

- (void)stroke
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL)
        return;
    CGContextSaveGState(context);
    CGContextSetLineWidth(context, _lightgramLineWidth);
    CGContextSetLineCap(context, _lightgramLineCapStyle);
    CGContextSetLineJoin(context, _lightgramLineJoinStyle);
    CGContextAddPath(context, _lightgramPath);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
}

- (void)addClip
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL)
        return;
    CGContextAddPath(context, _lightgramPath);
    if (_lightgramUsesEvenOddFillRule)
        CGContextEOClip(context);
    else
        CGContextClip(context);
}

@end

static NSInteger LightGramIOS3CompareArrayObjects(id lhs, id rhs, void *context)
{
    NSComparisonResult (^comparator)(id, id) = context;
    return comparator(lhs, rhs);
}

static NSInteger LightGramIOS3CompareStableArrayObjects(id lhs, id rhs, void *context)
{
    NSComparisonResult (^comparator)(id, id) = context;
    NSComparisonResult result = comparator([lhs objectAtIndex:0], [rhs objectAtIndex:0]);
    return result == NSOrderedSame ? [[lhs objectAtIndex:1] compare:[rhs objectAtIndex:1]] : result;
}

@implementation NSMutableArray (LightGramIOS3SortingCompatibilityFallback)

- (void)lightgramIOS3Fallback_sortUsingComparator:(NSComparisonResult (^)(id obj1, id obj2))cmptr
{
    [self sortWithOptions:0 usingComparator:cmptr];
}

- (void)lightgramIOS3Fallback_sortWithOptions:(NSSortOptions)opts usingComparator:(NSComparisonResult (^)(id obj1, id obj2))cmptr
{
    if (cmptr == nil || self.count < 2)
        return;

    if ((opts & NSSortStable) == 0)
    {
        [self sortUsingFunction:LightGramIOS3CompareArrayObjects context:cmptr];
        return;
    }

    NSMutableArray *indexed = [[NSMutableArray alloc] initWithCapacity:self.count];
    @try
    {
        NSUInteger index = 0;
        for (id object in self)
            [indexed addObject:[NSArray arrayWithObjects:object, [NSNumber numberWithUnsignedInteger:index++], nil]];
        [indexed sortUsingFunction:LightGramIOS3CompareStableArrayObjects context:cmptr];
        index = 0;
        for (NSArray *entry in indexed)
            [self replaceObjectAtIndex:index++ withObject:[entry objectAtIndex:0]];
    }
    @finally
    {
        [indexed release];
    }
}

@end


static BOOL LightGramIOS3TextCheckingWhitespace(unichar c)
{
    return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == 0x00a0;
}

static BOOL LightGramIOS3TextCheckingTokenBoundary(unichar c)
{
    return LightGramIOS3TextCheckingWhitespace(c) || c == '<' || c == '>' || c == '"' || c == 0x201c || c == 0x201d;
}

static BOOL LightGramIOS3TextCheckingLeadingDelimiter(unichar c)
{
    return c == '(' || c == '[' || c == '{' || c == '\'' || c == 0x2018 || c == 0x2019;
}

static BOOL LightGramIOS3TextCheckingTrailingDelimiter(unichar c)
{
    return c == '.' || c == ',' || c == '!' || c == '?' || c == ';' || c == ':' || c == '\'' || c == 0x2018 || c == 0x2019 || c == ']' || c == '}';
}

static BOOL LightGramIOS3TextCheckingASCIIAlpha(unichar c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

static BOOL LightGramIOS3TextCheckingASCIIDigit(unichar c)
{
    return c >= '0' && c <= '9';
}

static BOOL LightGramIOS3TextCheckingSchemeCharacter(unichar c)
{
    return LightGramIOS3TextCheckingASCIIAlpha(c) || LightGramIOS3TextCheckingASCIIDigit(c) || c == '+' || c == '-' || c == '.';
}

static BOOL LightGramIOS3TextCheckingValidScheme(NSString *string, NSUInteger colon)
{
    if (colon == 0 || !LightGramIOS3TextCheckingASCIIAlpha([string characterAtIndex:0]))
        return NO;
    for (NSUInteger i = 1; i < colon; i++)
    {
        if (!LightGramIOS3TextCheckingSchemeCharacter([string characterAtIndex:i]))
            return NO;
    }
    return YES;
}

static BOOL LightGramIOS3TextCheckingValidIPv4(NSString *host)
{
    NSArray *parts = [host componentsSeparatedByString:@"."];
    if ([parts count] != 4)
        return NO;
    for (NSString *part in parts)
    {
        if ([part length] == 0 || [part length] > 3)
            return NO;
        NSInteger value = 0;
        for (NSUInteger i = 0; i < [part length]; i++)
        {
            unichar c = [part characterAtIndex:i];
            if (!LightGramIOS3TextCheckingASCIIDigit(c))
                return NO;
            value = value * 10 + (c - '0');
        }
        if (value > 255)
            return NO;
    }
    return YES;
}

static BOOL LightGramIOS3TextCheckingValidDomain(NSString *host)
{
    if ([host length] < 4 || [host hasPrefix:@"."] || [host hasSuffix:@"."])
        return NO;
    if (LightGramIOS3TextCheckingValidIPv4(host))
        return YES;

    NSRange lastDot = [host rangeOfString:@"." options:NSBackwardsSearch];
    if (lastDot.location == NSNotFound || lastDot.location == 0 || NSMaxRange(lastDot) >= [host length])
        return NO;

    NSString *tld = [host substringFromIndex:NSMaxRange(lastDot)];
    if ([tld hasPrefix:@"xn--"])
    {
        if ([tld length] <= 4)
            return NO;
    }
    else
    {
        if ([tld length] < 2 || [tld length] > 24)
            return NO;
        for (NSUInteger i = 0; i < [tld length]; i++)
        {
            if (!LightGramIOS3TextCheckingASCIIAlpha([tld characterAtIndex:i]))
                return NO;
        }
    }

    NSArray *labels = [host componentsSeparatedByString:@"."];
    for (NSString *label in labels)
    {
        if ([label length] == 0 || [label length] > 63 || [label hasPrefix:@"-"] || [label hasSuffix:@"-"])
            return NO;
        for (NSUInteger i = 0; i < [label length]; i++)
        {
            unichar c = [label characterAtIndex:i];
            if (!(LightGramIOS3TextCheckingASCIIAlpha(c) || LightGramIOS3TextCheckingASCIIDigit(c) || c == '-'))
                return NO;
        }
    }
    return YES;
}

static BOOL LightGramIOS3TextCheckingValidEmail(NSString *string)
{
    NSRange at = [string rangeOfString:@"@" options:NSBackwardsSearch];
    if (at.location == NSNotFound || at.location == 0 || NSMaxRange(at) >= [string length])
        return NO;
    if ([string rangeOfString:@"@" options:0 range:NSMakeRange(0, at.location)].location != NSNotFound)
        return NO;

    NSString *local = [string substringToIndex:at.location];
    NSString *host = [string substringFromIndex:NSMaxRange(at)];
    if ([local hasPrefix:@"."] || [local hasSuffix:@"."] || [local rangeOfString:@".."].location != NSNotFound)
        return NO;
    for (NSUInteger i = 0; i < [local length]; i++)
    {
        unichar c = [local characterAtIndex:i];
        if (!(LightGramIOS3TextCheckingASCIIAlpha(c) || LightGramIOS3TextCheckingASCIIDigit(c) || c == '.' || c == '_' || c == '%' || c == '+' || c == '-'))
            return NO;
    }
    return LightGramIOS3TextCheckingValidDomain(host);
}

static NSString *LightGramIOS3TextCheckingHostFromCandidate(NSString *candidate)
{
    NSUInteger end = [candidate length];
    for (NSUInteger i = 0; i < [candidate length]; i++)
    {
        unichar c = [candidate characterAtIndex:i];
        if (c == '/' || c == '?' || c == '#')
        {
            end = i;
            break;
        }
    }
    if (end == 0)
        return nil;
    NSString *hostPort = [candidate substringToIndex:end];
    NSRange colon = [hostPort rangeOfString:@":" options:NSBackwardsSearch];
    if (colon.location != NSNotFound)
    {
        NSString *port = [hostPort substringFromIndex:NSMaxRange(colon)];
        if ([port length] == 0)
            return nil;
        for (NSUInteger i = 0; i < [port length]; i++)
        {
            if (!LightGramIOS3TextCheckingASCIIDigit([port characterAtIndex:i]))
                return nil;
        }
        hostPort = [hostPort substringToIndex:colon.location];
    }
    return hostPort;
}

static NSURL *LightGramIOS3TextCheckingURLForCandidate(NSString *candidate)
{
    NSString *urlString = nil;
    NSRange colon = [candidate rangeOfString:@":"];
    if (colon.location != NSNotFound && LightGramIOS3TextCheckingValidScheme(candidate, colon.location))
    {
        NSString *scheme = [[candidate substringToIndex:colon.location] lowercaseString];
        if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"] || [scheme isEqualToString:@"ftp"] || [scheme isEqualToString:@"ftps"] || [scheme isEqualToString:@"mailto"])
            urlString = candidate;
    }

    if (urlString == nil && LightGramIOS3TextCheckingValidEmail(candidate))
    {
        urlString = [@"mailto:" stringByAppendingString:candidate];
    }
    else if (urlString == nil)
    {
        NSString *lower = [candidate lowercaseString];
        NSString *host = LightGramIOS3TextCheckingHostFromCandidate(candidate);
        if (host != nil && ([lower hasPrefix:@"www."] || LightGramIOS3TextCheckingValidDomain(host)))
            urlString = [@"http://" stringByAppendingString:candidate];
    }

    if (urlString == nil)
        return nil;
    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil)
        url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    return url;
}

static BOOL LightGramIOS3TextCheckingAllDigits(NSString *string)
{
    if ([string length] == 0)
        return NO;
    for (NSUInteger i = 0; i < [string length]; i++)
    {
        if (!LightGramIOS3TextCheckingASCIIDigit([string characterAtIndex:i]))
            return NO;
    }
    return YES;
}

static BOOL LightGramIOS3TextCheckingLooksLikeDateOrIPv4(NSString *candidate)
{
    if ([candidate rangeOfString:@" "].location != NSNotFound || [candidate rangeOfString:@"\t"].location != NSNotFound || [candidate rangeOfString:@"("].location != NSNotFound || [candidate rangeOfString:@")"].location != NSNotFound || [candidate rangeOfString:@"+"].location != NSNotFound)
        return NO;

    NSString *separator = nil;
    if ([candidate rangeOfString:@"."].location != NSNotFound && [candidate rangeOfString:@"-"].location == NSNotFound)
        separator = @".";
    else if ([candidate rangeOfString:@"-"].location != NSNotFound && [candidate rangeOfString:@"."].location == NSNotFound)
        separator = @"-";
    if (separator == nil)
        return NO;

    NSArray *groups = [candidate componentsSeparatedByString:separator];
    for (NSString *group in groups)
    {
        if (!LightGramIOS3TextCheckingAllDigits(group))
            return NO;
    }

    if ([separator isEqualToString:@"."] && [groups count] == 4)
    {
        BOOL ipv4 = YES;
        for (NSString *group in groups)
        {
            if ([group length] > 3 || [group integerValue] > 255)
            {
                ipv4 = NO;
                break;
            }
        }
        if (ipv4)
            return YES;
    }

    if ([groups count] == 3)
    {
        NSString *first = [groups objectAtIndex:0];
        NSString *second = [groups objectAtIndex:1];
        NSString *third = [groups objectAtIndex:2];
        if ([first length] == 4 && [second length] <= 2 && [third length] <= 2)
        {
            NSInteger month = [second integerValue];
            NSInteger day = [third integerValue];
            if (month >= 1 && month <= 12 && day >= 1 && day <= 31)
                return YES;
        }
        if ([third length] == 4 && [first length] <= 2 && [second length] <= 2)
        {
            NSInteger firstValue = [first integerValue];
            NSInteger secondValue = [second integerValue];
            if ((firstValue >= 1 && firstValue <= 31 && secondValue >= 1 && secondValue <= 12) || (firstValue >= 1 && firstValue <= 12 && secondValue >= 1 && secondValue <= 31))
                return YES;
        }
    }

    return NO;
}

static BOOL LightGramIOS3TextCheckingRangesOverlap(NSRange a, NSRange b)
{
    return a.location < NSMaxRange(b) && b.location < NSMaxRange(a);
}

static BOOL LightGramIOS3TextCheckingResultOverlaps(NSArray *results, NSRange range)
{
    for (LightGramIOS3TextCheckingResult *result in results)
    {
        if (LightGramIOS3TextCheckingRangesOverlap([result range], range))
            return YES;
    }
    return NO;
}

@implementation LightGramIOS3TextCheckingResult

+ (LightGramIOS3TextCheckingResult *)linkCheckingResultWithRange:(NSRange)range URL:(NSURL *)url
{
    return [[[self alloc] initWithResultType:NSTextCheckingTypeLink range:range URL:url phoneNumber:nil] autorelease];
}

+ (LightGramIOS3TextCheckingResult *)phoneNumberCheckingResultWithRange:(NSRange)range phoneNumber:(NSString *)phoneNumber
{
    return [[[self alloc] initWithResultType:NSTextCheckingTypePhoneNumber range:range URL:nil phoneNumber:phoneNumber] autorelease];
}

+ (LightGramIOS3TextCheckingResult *)regularExpressionCheckingResultWithRanges:(NSArray *)ranges
{
    return [[[self alloc] initWithRanges:ranges] autorelease];
}

- (instancetype)initWithResultType:(NSTextCheckingType)resultType range:(NSRange)range URL:(NSURL *)url phoneNumber:(NSString *)phoneNumber
{
    self = [super init];
    if (self != nil)
    {
        _lightgramResultType = resultType;
        _lightgramRange = range;
        _lightgramURL = [url retain];
        _lightgramPhoneNumber = [phoneNumber copy];
        _lightgramRanges = [[NSArray alloc] initWithObjects:[NSValue valueWithRange:range], nil];
    }
    return self;
}

- (instancetype)initWithRanges:(NSArray *)ranges
{
    self = [super init];
    if (self != nil)
    {
        _lightgramResultType = NSTextCheckingTypeRegularExpression;
        _lightgramRanges = [ranges copy];
        if ([_lightgramRanges count] != 0)
            _lightgramRange = [[_lightgramRanges objectAtIndex:0] rangeValue];
        else
            _lightgramRange = NSMakeRange(NSNotFound, 0);
    }
    return self;
}

- (void)dealloc
{
    [_lightgramURL release];
    [_lightgramPhoneNumber release];
    [_lightgramRanges release];
    [super dealloc];
}

- (NSTextCheckingType)resultType
{
    return _lightgramResultType;
}

- (NSRange)range
{
    return _lightgramRange;
}

- (NSURL *)URL
{
    return _lightgramURL;
}

- (NSString *)phoneNumber
{
    return _lightgramPhoneNumber;
}

- (LightGramIOS3TextCheckingResult *)resultByAdjustingRangesWithOffset:(NSInteger)offset
{
    if ([_lightgramRanges count] > 1 || _lightgramResultType == NSTextCheckingTypeRegularExpression)
    {
        NSMutableArray *ranges = [NSMutableArray arrayWithCapacity:[_lightgramRanges count]];
        for (NSValue *value in _lightgramRanges)
        {
            NSRange range = [value rangeValue];
            if (range.location != NSNotFound)
            {
                NSInteger location = (NSInteger)range.location + offset;
                if (location < 0)
                    location = 0;
                range.location = (NSUInteger)location;
            }
            [ranges addObject:[NSValue valueWithRange:range]];
        }
        return [[[LightGramIOS3TextCheckingResult alloc] initWithRanges:ranges] autorelease];
    }
    NSInteger location = (NSInteger)_lightgramRange.location + offset;
    if (location < 0)
        location = 0;
    return [[[LightGramIOS3TextCheckingResult alloc] initWithResultType:_lightgramResultType range:NSMakeRange((NSUInteger)location, _lightgramRange.length) URL:_lightgramURL phoneNumber:_lightgramPhoneNumber] autorelease];
}

- (NSUInteger)numberOfRanges
{
    return [_lightgramRanges count];
}

- (NSRange)rangeAtIndex:(NSUInteger)idx
{
    if (idx >= [_lightgramRanges count])
        return NSMakeRange(NSNotFound, 0);
    return [[_lightgramRanges objectAtIndex:idx] rangeValue];
}

@end

@interface LightGramIOS3CacheEntry : NSObject
{
    id _lightgramKey;
    id _lightgramObject;
    NSUInteger _lightgramCost;
    LightGramIOS3CacheEntry *_lightgramPrevious;
    LightGramIOS3CacheEntry *_lightgramNext;
}
- (instancetype)initWithKey:(id)key object:(id)object cost:(NSUInteger)cost;
@property (nonatomic, readonly, retain) id key;
@property (nonatomic, readonly, retain) id object;
@property (nonatomic, readonly) NSUInteger cost;
@property (nonatomic, assign) LightGramIOS3CacheEntry *previous;
@property (nonatomic, assign) LightGramIOS3CacheEntry *next;
@end

@implementation LightGramIOS3CacheEntry

- (instancetype)initWithKey:(id)key object:(id)object cost:(NSUInteger)cost
{
    self = [super init];
    if (self != nil)
    {
        _lightgramKey = [key retain];
        _lightgramObject = [object retain];
        _lightgramCost = cost;
    }
    return self;
}

- (void)dealloc
{
    [_lightgramKey release];
    [_lightgramObject release];
    [super dealloc];
}

- (id)key
{
    return _lightgramKey;
}

- (id)object
{
    return _lightgramObject;
}

- (NSUInteger)cost
{
    return _lightgramCost;
}

- (LightGramIOS3CacheEntry *)previous
{
    return _lightgramPrevious;
}

- (void)setPrevious:(LightGramIOS3CacheEntry *)previous
{
    _lightgramPrevious = previous;
}

- (LightGramIOS3CacheEntry *)next
{
    return _lightgramNext;
}

- (void)setNext:(LightGramIOS3CacheEntry *)next
{
    _lightgramNext = next;
}

@end

@implementation LightGramIOS3Cache

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _lightgramEntriesByKey = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        if (_lightgramEntriesByKey == NULL)
        {
            [self release];
            return nil;
        }
        _lightgramLock = [[NSRecursiveLock alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(lightgramMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_lightgramEntriesByKey != NULL)
        CFRelease(_lightgramEntriesByKey);
    [_lightgramLock release];
    [super dealloc];
}

- (void)lightgramMemoryWarning:(NSNotification *)notification
{
    (void)notification;
    [self removeAllObjects];
}

- (LightGramIOS3CacheEntry *)lightgramEntryForKey:(id)key
{
    if (key == nil || _lightgramEntriesByKey == NULL)
        return nil;
    return (LightGramIOS3CacheEntry *)CFDictionaryGetValue(_lightgramEntriesByKey, key);
}

- (NSUInteger)lightgramEntryCount
{
    return _lightgramEntriesByKey == NULL ? 0 : (NSUInteger)CFDictionaryGetCount(_lightgramEntriesByKey);
}

- (void)lightgramDetachEntry:(LightGramIOS3CacheEntry *)entry
{
    LightGramIOS3CacheEntry *previous = entry.previous;
    LightGramIOS3CacheEntry *next = entry.next;

    if (previous != nil)
        previous.next = next;
    else
        _lightgramOldestEntry = next;

    if (next != nil)
        next.previous = previous;
    else
        _lightgramNewestEntry = previous;

    entry.previous = nil;
    entry.next = nil;
}

- (void)lightgramAppendEntry:(LightGramIOS3CacheEntry *)entry
{
    entry.previous = _lightgramNewestEntry;
    entry.next = nil;

    if (_lightgramNewestEntry != nil)
        _lightgramNewestEntry.next = entry;
    else
        _lightgramOldestEntry = entry;

    _lightgramNewestEntry = entry;
}

- (void)lightgramTouchEntry:(LightGramIOS3CacheEntry *)entry
{
    if (entry == nil || entry == _lightgramNewestEntry)
        return;
    [self lightgramDetachEntry:entry];
    [self lightgramAppendEntry:entry];
}

- (void)lightgramRemoveEntry:(LightGramIOS3CacheEntry *)entry
{
    if (entry == nil)
        return;

    if (_lightgramTotalCost >= entry.cost)
        _lightgramTotalCost -= entry.cost;
    else
        _lightgramTotalCost = 0;

    [entry retain];
    [self lightgramDetachEntry:entry];
    CFDictionaryRemoveValue(_lightgramEntriesByKey, entry.key);
    [entry release];
}

- (void)lightgramTrim
{
    while ((_lightgramCountLimit != 0 && [self lightgramEntryCount] > _lightgramCountLimit) || (_lightgramTotalCostLimit != 0 && _lightgramTotalCost > _lightgramTotalCostLimit))
    {
        LightGramIOS3CacheEntry *entry = _lightgramOldestEntry;
        if (entry == nil)
            break;
        [self lightgramRemoveEntry:entry];
    }
}

- (id)objectForKey:(id)key
{
    if (key == nil)
        return nil;
    [_lightgramLock lock];
    LightGramIOS3CacheEntry *entry = [self lightgramEntryForKey:key];
    id object = [[entry object] retain];
    [self lightgramTouchEntry:entry];
    [_lightgramLock unlock];
    return [object autorelease];
}

- (void)setObject:(id)object forKey:(id)key
{
    [self setObject:object forKey:key cost:0];
}

- (void)setObject:(id)object forKey:(id)key cost:(NSUInteger)cost
{
    if (object == nil || key == nil)
        return;
    [_lightgramLock lock];
    LightGramIOS3CacheEntry *previous = [self lightgramEntryForKey:key];
    if (previous != nil)
        [self lightgramRemoveEntry:previous];

    LightGramIOS3CacheEntry *entry = [[LightGramIOS3CacheEntry alloc] initWithKey:key object:object cost:cost];
    CFDictionarySetValue(_lightgramEntriesByKey, key, entry);
    [self lightgramAppendEntry:entry];
    _lightgramTotalCost += cost;
    [entry release];

    [self lightgramTrim];
    [_lightgramLock unlock];
}

- (void)removeObjectForKey:(id)key
{
    if (key == nil)
        return;
    [_lightgramLock lock];
    [self lightgramRemoveEntry:[self lightgramEntryForKey:key]];
    [_lightgramLock unlock];
}

- (void)removeAllObjects
{
    [_lightgramLock lock];
    _lightgramOldestEntry = nil;
    _lightgramNewestEntry = nil;
    CFDictionaryRemoveAllValues(_lightgramEntriesByKey);
    _lightgramTotalCost = 0;
    [_lightgramLock unlock];
}

- (NSUInteger)countLimit
{
    [_lightgramLock lock];
    NSUInteger value = _lightgramCountLimit;
    [_lightgramLock unlock];
    return value;
}

- (void)setCountLimit:(NSUInteger)countLimit
{
    [_lightgramLock lock];
    _lightgramCountLimit = countLimit;
    [self lightgramTrim];
    [_lightgramLock unlock];
}

- (NSUInteger)totalCostLimit
{
    [_lightgramLock lock];
    NSUInteger value = _lightgramTotalCostLimit;
    [_lightgramLock unlock];
    return value;
}

- (void)setTotalCostLimit:(NSUInteger)totalCostLimit
{
    [_lightgramLock lock];
    _lightgramTotalCostLimit = totalCostLimit;
    [self lightgramTrim];
    [_lightgramLock unlock];
}

@end


static NSUInteger LightGramIOS3RegexUTF16LengthForBytes(const char *bytes, size_t length)
{
    if (length == 0)
        return 0;
    NSString *string = [[[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding] autorelease];
    return string == nil ? (NSUInteger)length : [string length];
}

static NSString *LightGramIOS3RegexNormalizePattern(NSString *pattern)
{
    return [pattern stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
}

@implementation LightGramIOS3RegularExpression

+ (LightGramIOS3RegularExpression *)regularExpressionWithPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options error:(NSError **)error
{
    return [[[self alloc] initWithPattern:pattern options:options error:error] autorelease];
}

- (instancetype)initWithPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options error:(NSError **)error
{
    self = [super init];
    if (self != nil)
    {
        _lightgramPattern = [pattern copy];
        _lightgramOptions = options;
        regex_t *compiled = calloc(1, sizeof(regex_t));
        NSString *normalizedPattern = LightGramIOS3RegexNormalizePattern(pattern == nil ? @"" : pattern);
        const char *utf8Pattern = [normalizedPattern UTF8String];
        int flags = REG_EXTENDED;
        if ((options & NSRegularExpressionCaseInsensitive) != 0)
            flags |= REG_ICASE;
        int result = regcomp(compiled, utf8Pattern == NULL ? "" : utf8Pattern, flags);
        if (result != 0)
        {
            if (error != NULL)
            {
                char buffer[256];
                regerror(result, compiled, buffer, sizeof(buffer));
                NSString *description = [NSString stringWithUTF8String:buffer];
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:2048 userInfo:[NSDictionary dictionaryWithObject:(description == nil ? @"Invalid regular expression" : description) forKey:NSLocalizedDescriptionKey]];
            }
            free(compiled);
            [_lightgramPattern release];
            [self release];
            return nil;
        }
        _lightgramCompiledExpression = compiled;
        _lightgramCaptureCount = compiled->re_nsub;
    }
    return self;
}

- (void)dealloc
{
    if (_lightgramCompiledExpression != NULL)
    {
        regex_t *compiled = (regex_t *)_lightgramCompiledExpression;
        regfree(compiled);
        free(compiled);
    }
    [_lightgramPattern release];
    [super dealloc];
}

- (NSString *)pattern
{
    return _lightgramPattern;
}

- (NSRegularExpressionOptions)options
{
    return _lightgramOptions;
}

- (NSUInteger)numberOfCaptureGroups
{
    return _lightgramCaptureCount;
}

- (NSArray *)matchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range
{
    (void)options;
    if (string == nil || _lightgramCompiledExpression == NULL || range.location == NSNotFound || NSMaxRange(range) > [string length])
        return [NSArray array];
    NSString *subject = [string substringWithRange:range];
    NSData *data = [subject dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil)
        return [NSArray array];
    NSMutableData *terminatedData = [NSMutableData dataWithData:data];
    unsigned char zero = 0;
    [terminatedData appendBytes:&zero length:1];
    const char *bytes = (const char *)[terminatedData bytes];
    size_t byteLength = [data length];
    regex_t *compiled = (regex_t *)_lightgramCompiledExpression;
    size_t matchCount = _lightgramCaptureCount + 1;
    regmatch_t *matches = calloc(matchCount, sizeof(regmatch_t));
    NSMutableArray *results = [NSMutableArray array];
    size_t cursor = 0;
    BOOL firstAttempt = YES;
    while (cursor <= byteLength)
    {
        int flags = firstAttempt ? 0 : REG_NOTBOL;
        int status = regexec(compiled, bytes + cursor, matchCount, matches, flags);
        if (status != 0)
            break;
        if (matches[0].rm_so < 0 || matches[0].rm_eo < matches[0].rm_so)
            break;
        size_t absoluteStart = cursor + (size_t)matches[0].rm_so;
        size_t absoluteEnd = cursor + (size_t)matches[0].rm_eo;
        NSMutableArray *ranges = [NSMutableArray arrayWithCapacity:matchCount];
        for (size_t index = 0; index < matchCount; index++)
        {
            if (matches[index].rm_so < 0)
            {
                [ranges addObject:[NSValue valueWithRange:NSMakeRange(NSNotFound, 0)]];
                continue;
            }
            size_t captureStart = cursor + (size_t)matches[index].rm_so;
            size_t captureEnd = cursor + (size_t)matches[index].rm_eo;
            NSUInteger utf16Start = LightGramIOS3RegexUTF16LengthForBytes(bytes, captureStart);
            NSUInteger utf16End = LightGramIOS3RegexUTF16LengthForBytes(bytes, captureEnd);
            [ranges addObject:[NSValue valueWithRange:NSMakeRange(range.location + utf16Start, utf16End - utf16Start)]];
        }
        [results addObject:[LightGramIOS3TextCheckingResult regularExpressionCheckingResultWithRanges:ranges]];
        if (absoluteEnd > absoluteStart)
            cursor = absoluteEnd;
        else
        {
            if (absoluteEnd >= byteLength)
                break;
            cursor = absoluteEnd + 1;
            while (cursor < byteLength && (((const unsigned char *)bytes)[cursor] & 0xc0) == 0x80)
                cursor++;
        }
        firstAttempt = NO;
    }
    free(matches);
    return results;
}

- (LightGramIOS3TextCheckingResult *)firstMatchInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range
{
    NSArray *matches = [self matchesInString:string options:options range:range];
    return [matches count] == 0 ? nil : [matches objectAtIndex:0];
}

- (NSUInteger)numberOfMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range
{
    return [[self matchesInString:string options:options range:range] count];
}

- (NSRange)rangeOfFirstMatchInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range
{
    LightGramIOS3TextCheckingResult *result = [self firstMatchInString:string options:options range:range];
    return result == nil ? NSMakeRange(NSNotFound, 0) : [result range];
}

- (NSString *)lightgramReplacementForTemplate:(NSString *)templ result:(LightGramIOS3TextCheckingResult *)result source:(NSString *)source
{
    NSMutableString *replacement = [NSMutableString string];
    NSUInteger length = [templ length];
    for (NSUInteger index = 0; index < length; index++)
    {
        unichar character = [templ characterAtIndex:index];
        if (character == '$' && index + 1 < length)
        {
            unichar digit = [templ characterAtIndex:index + 1];
            if (digit >= '0' && digit <= '9')
            {
                NSUInteger rangeIndex = (NSUInteger)(digit - '0');
                NSRange captureRange = [result rangeAtIndex:rangeIndex];
                if (captureRange.location != NSNotFound && NSMaxRange(captureRange) <= [source length])
                    [replacement appendString:[source substringWithRange:captureRange]];
                index++;
                continue;
            }
        }
        [replacement appendFormat:@"%C", character];
    }
    return replacement;
}

- (NSString *)stringByReplacingMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range withTemplate:(NSString *)templ
{
    if (string == nil)
        return nil;
    NSArray *matches = [self matchesInString:string options:options range:range];
    if ([matches count] == 0)
        return string;
    NSMutableString *result = [string mutableCopy];
    for (NSInteger index = (NSInteger)[matches count] - 1; index >= 0; index--)
    {
        LightGramIOS3TextCheckingResult *match = [matches objectAtIndex:(NSUInteger)index];
        NSRange matchRange = [match range];
        if (matchRange.location == NSNotFound || NSMaxRange(matchRange) > [result length])
            continue;
        NSString *replacement = [self lightgramReplacementForTemplate:(templ == nil ? @"" : templ) result:match source:string];
        [result replaceCharactersInRange:matchRange withString:replacement];
    }
    return [result autorelease];
}

@end

@implementation LightGramIOS3DataDetector

+ (LightGramIOS3DataDetector *)dataDetectorWithTypes:(NSTextCheckingType)checkingTypes error:(NSError **)error
{
    return [[[self alloc] initWithTypes:checkingTypes error:error] autorelease];
}

- (instancetype)initWithTypes:(NSTextCheckingType)checkingTypes error:(NSError **)error
{
    self = [super init];
    if (self != nil)
        _lightgramCheckingTypes = checkingTypes & (NSTextCheckingTypeLink | NSTextCheckingTypePhoneNumber);
    if (error != NULL)
        *error = nil;
    return self;
}

- (NSArray *)matchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range
{
    (void)options;
    if (string == nil || range.location == NSNotFound || range.location >= [string length] || range.length == 0)
        return [NSArray array];

    NSUInteger stringLength = [string length];
    NSUInteger limit = range.length > stringLength - range.location ? stringLength : range.location + range.length;
    NSMutableArray *results = [NSMutableArray array];

    if ((_lightgramCheckingTypes & NSTextCheckingTypeLink) != 0)
    {
        NSUInteger index = range.location;
        while (index < limit)
        {
            while (index < limit && LightGramIOS3TextCheckingTokenBoundary([string characterAtIndex:index]))
                index++;
            NSUInteger tokenStart = index;
            while (index < limit && !LightGramIOS3TextCheckingTokenBoundary([string characterAtIndex:index]))
                index++;
            NSUInteger tokenEnd = index;

            while (tokenStart < tokenEnd && LightGramIOS3TextCheckingLeadingDelimiter([string characterAtIndex:tokenStart]))
                tokenStart++;
            while (tokenEnd > tokenStart && LightGramIOS3TextCheckingTrailingDelimiter([string characterAtIndex:tokenEnd - 1]))
                tokenEnd--;
            while (tokenEnd > tokenStart && [string characterAtIndex:tokenEnd - 1] == ')')
            {
                NSUInteger opens = 0;
                NSUInteger closes = 0;
                for (NSUInteger i = tokenStart; i < tokenEnd; i++)
                {
                    unichar c = [string characterAtIndex:i];
                    if (c == '(')
                        opens++;
                    else if (c == ')')
                        closes++;
                }
                if (closes <= opens)
                    break;
                tokenEnd--;
            }

            if (tokenEnd > tokenStart)
            {
                NSRange tokenRange = NSMakeRange(tokenStart, tokenEnd - tokenStart);
                NSString *candidate = [string substringWithRange:tokenRange];
                NSURL *url = LightGramIOS3TextCheckingURLForCandidate(candidate);
                if (url != nil)
                    [results addObject:[LightGramIOS3TextCheckingResult linkCheckingResultWithRange:tokenRange URL:url]];
            }
        }
    }

    if ((_lightgramCheckingTypes & NSTextCheckingTypePhoneNumber) != 0)
    {
        NSUInteger index = range.location;
        while (index < limit)
        {
            unichar first = [string characterAtIndex:index];
            BOOL possibleStart = LightGramIOS3TextCheckingASCIIDigit(first) || first == '+' || first == '(';
            if (!possibleStart)
            {
                index++;
                continue;
            }

            if (index > range.location)
            {
                unichar previous = [string characterAtIndex:index - 1];
                if (LightGramIOS3TextCheckingASCIIAlpha(previous) || LightGramIOS3TextCheckingASCIIDigit(previous))
                {
                    index++;
                    continue;
                }
            }

            NSUInteger end = index;
            NSUInteger digitCount = 0;
            while (end < limit)
            {
                unichar c = [string characterAtIndex:end];
                if (LightGramIOS3TextCheckingASCIIDigit(c))
                {
                    digitCount++;
                    end++;
                    continue;
                }
                if (c == '+' && end == index)
                {
                    end++;
                    continue;
                }
                if (c == ' ' || c == '\t' || c == 0x00a0 || c == '-' || c == '(' || c == ')' || c == '.')
                {
                    end++;
                    continue;
                }
                break;
            }

            NSUInteger trimmedEnd = end;
            while (trimmedEnd > index)
            {
                unichar c = [string characterAtIndex:trimmedEnd - 1];
                if (LightGramIOS3TextCheckingASCIIDigit(c))
                    break;
                trimmedEnd--;
            }

            if (digitCount >= 7 && digitCount <= 15 && trimmedEnd > index)
            {
                if (trimmedEnd == limit || !(LightGramIOS3TextCheckingASCIIAlpha([string characterAtIndex:trimmedEnd]) || LightGramIOS3TextCheckingASCIIDigit([string characterAtIndex:trimmedEnd])))
                {
                    NSRange phoneRange = NSMakeRange(index, trimmedEnd - index);
                    if (!LightGramIOS3TextCheckingResultOverlaps(results, phoneRange))
                    {
                        NSString *phoneNumber = [string substringWithRange:phoneRange];
                        if (!LightGramIOS3TextCheckingLooksLikeDateOrIPv4(phoneNumber))
                            [results addObject:[LightGramIOS3TextCheckingResult phoneNumberCheckingResultWithRange:phoneRange phoneNumber:phoneNumber]];
                    }
                }
            }

            index = end > index ? end : index + 1;
        }
    }

    [results sortUsingComparator:^NSComparisonResult(id aObject, id bObject) {
        LightGramIOS3TextCheckingResult *a = aObject;
        LightGramIOS3TextCheckingResult *b = bObject;
        if ([a range].location < [b range].location)
            return NSOrderedAscending;
        if ([a range].location > [b range].location)
            return NSOrderedDescending;
        if ([a range].length > [b range].length)
            return NSOrderedAscending;
        if ([a range].length < [b range].length)
            return NSOrderedDescending;
        return NSOrderedSame;
    }];

    return results;
}

- (void)enumerateMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range usingBlock:(void (^)(LightGramIOS3TextCheckingResult *result, NSMatchingFlags flags, BOOL *stop))block
{
    if (block == nil)
        return;
    BOOL stop = NO;
    for (LightGramIOS3TextCheckingResult *result in [self matchesInString:string options:options range:range])
    {
        block(result, 0, &stop);
        if (stop)
            break;
    }
}

@end

@interface LightGramIOS3AnimationCompletionTarget : NSObject
{
    void (^_completion)(BOOL);
}
- (instancetype)initWithCompletion:(void (^)(BOOL))completion;
- (void)fire:(NSTimer *)timer;
@end

@implementation LightGramIOS3AnimationCompletionTarget

- (instancetype)initWithCompletion:(void (^)(BOOL))completion
{
    self = [super init];
    if (self != nil)
        _completion = [completion copy];
    return self;
}

- (void)dealloc
{
    [_completion release];
    [super dealloc];
}

- (void)fire:(NSTimer *)timer
{
    if (_completion != nil)
        _completion(YES);
    [self release];
}

@end

static NSString *const LightGramIOS3KeyframeAnimationStackKey = @"LightGramIOS3KeyframeAnimationStack";

static NSMutableArray *LightGramIOS3KeyframeAnimationStack(void)
{
    NSMutableDictionary *dictionary = [[NSThread currentThread] threadDictionary];
    NSMutableArray *stack = [dictionary objectForKey:LightGramIOS3KeyframeAnimationStackKey];
    if (stack == nil)
    {
        stack = [NSMutableArray array];
        [dictionary setObject:stack forKey:LightGramIOS3KeyframeAnimationStackKey];
    }
    return stack;
}

static const void *LightGramIOS3GestureRecognizerRegistryKey = &LightGramIOS3GestureRecognizerRegistryKey;
static const void *LightGramIOS3GestureRecognizerViewKey = &LightGramIOS3GestureRecognizerViewKey;

static UIView *LightGramIOS3GestureRecognizerView(id gestureRecognizer)
{
    return objc_getAssociatedObject(gestureRecognizer, LightGramIOS3GestureRecognizerViewKey);
}

static void LightGramIOS3SetGestureRecognizerView(id gestureRecognizer, UIView *view)
{
    objc_setAssociatedObject(gestureRecognizer, LightGramIOS3GestureRecognizerViewKey, view, OBJC_ASSOCIATION_ASSIGN);
}

@interface LightGramIOS3GestureRecognizerRegistry : NSObject
{
    UIView *_view;
    NSMutableArray *_recognizers;
    NSArray *_recognizerSnapshot;
}
- (instancetype)initWithView:(UIView *)view;
- (NSArray *)recognizerSnapshot;
- (void)lightgramUpdateRecognizerSnapshot;
- (void)addRecognizer:(UIGestureRecognizer *)gestureRecognizer;
- (void)removeRecognizer:(UIGestureRecognizer *)gestureRecognizer;
@end

@implementation LightGramIOS3GestureRecognizerRegistry

- (instancetype)initWithView:(UIView *)view
{
    self = [super init];
    if (self != nil)
    {
        _view = view;
        _recognizers = [[NSMutableArray alloc] init];
        _recognizerSnapshot = [[NSArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    for (UIGestureRecognizer *gestureRecognizer in _recognizers)
    {
        if (LightGramIOS3GestureRecognizerView(gestureRecognizer) == _view)
            LightGramIOS3SetGestureRecognizerView(gestureRecognizer, nil);
    }
    [_recognizers release];
    [_recognizerSnapshot release];
    [super dealloc];
}

- (NSArray *)recognizerSnapshot
{
    return _recognizerSnapshot;
}

- (void)lightgramUpdateRecognizerSnapshot
{
    NSArray *snapshot = [_recognizers copy];
    [_recognizerSnapshot release];
    _recognizerSnapshot = snapshot;
}

- (void)addRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer != nil && ![_recognizers containsObject:gestureRecognizer])
    {
        [_recognizers addObject:gestureRecognizer];
        [self lightgramUpdateRecognizerSnapshot];
    }
}

- (void)removeRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer != nil && [_recognizers containsObject:gestureRecognizer])
    {
        [_recognizers removeObject:gestureRecognizer];
        [self lightgramUpdateRecognizerSnapshot];
    }
}

@end

static LightGramIOS3GestureRecognizerRegistry *LightGramIOS3GestureRecognizerRegistryForView(UIView *view, BOOL create)
{
    LightGramIOS3GestureRecognizerRegistry *registry = objc_getAssociatedObject(view, LightGramIOS3GestureRecognizerRegistryKey);
    if (registry == nil && create)
    {
        registry = [[LightGramIOS3GestureRecognizerRegistry alloc] initWithView:view];
        objc_setAssociatedObject(view, LightGramIOS3GestureRecognizerRegistryKey, registry, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [registry release];
        registry = objc_getAssociatedObject(view, LightGramIOS3GestureRecognizerRegistryKey);
    }
    return registry;
}

@interface LightGramIOS3GestureTargetAction : NSObject
{
@public
    id target;
    SEL action;
}

- (instancetype)initWithTarget:(id)target action:(SEL)action;

@end

@implementation LightGramIOS3GestureTargetAction

- (instancetype)initWithTarget:(id)value action:(SEL)selector
{
    self = [super init];
    if (self != nil)
    {
        target = value;
        action = selector;
    }
    return self;
}

@end

@class LightGramIOS3GestureReference;

@interface UIGestureRecognizer (LightGramIOS3ReferenceTracking)
- (void)lightgramReferenceInvalidated:(LightGramIOS3GestureReference *)reference;
@end

@interface LightGramIOS3GestureReference : NSObject
{
    id _object;
    CFMutableSetRef _recognizers;
}
- (instancetype)initWithObject:(id)object;
- (id)object;
- (void)addRecognizer:(UIGestureRecognizer *)gestureRecognizer;
- (void)removeRecognizer:(UIGestureRecognizer *)gestureRecognizer;
- (void)invalidate;
@end

@implementation LightGramIOS3GestureReference

- (instancetype)initWithObject:(id)object
{
    self = [super init];
    if (self != nil)
    {
        _object = object;
        _recognizers = CFSetCreateMutable(kCFAllocatorDefault, 0, NULL);
    }
    return self;
}

- (void)dealloc
{
    CFRelease(_recognizers);
    [super dealloc];
}

- (id)object
{
    return _object;
}

- (void)addRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    CFSetAddValue(_recognizers, gestureRecognizer);
}

- (void)removeRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    CFSetRemoveValue(_recognizers, gestureRecognizer);
}

- (void)invalidate
{
    CFIndex count = CFSetGetCount(_recognizers);
    if (count > 0)
    {
        const void **recognizers = malloc(sizeof(void *) * (size_t)count);
        if (recognizers != NULL)
        {
            CFSetGetValues(_recognizers, recognizers);
            for (CFIndex index = 0; index < count; index++)
            {
                UIGestureRecognizer *gestureRecognizer = (UIGestureRecognizer *)recognizers[index];
                if (!CFSetContainsValue(_recognizers, gestureRecognizer))
                    continue;
                CFSetRemoveValue(_recognizers, gestureRecognizer);
                [gestureRecognizer lightgramReferenceInvalidated:self];
            }
            free(recognizers);
        }
        CFSetRemoveAllValues(_recognizers);
    }
    _object = nil;
}

@end

static const void *LightGramIOS3GestureReferenceSentinelKey = &LightGramIOS3GestureReferenceSentinelKey;

@interface LightGramIOS3GestureReferenceSentinel : NSObject
{
    LightGramIOS3GestureReference *_reference;
}
- (instancetype)initWithReference:(LightGramIOS3GestureReference *)reference;
- (LightGramIOS3GestureReference *)reference;
@end

@implementation LightGramIOS3GestureReferenceSentinel

- (instancetype)initWithReference:(LightGramIOS3GestureReference *)reference
{
    self = [super init];
    if (self != nil)
        _reference = [reference retain];
    return self;
}

- (void)dealloc
{
    [_reference invalidate];
    [_reference release];
    [super dealloc];
}

- (LightGramIOS3GestureReference *)reference
{
    return _reference;
}

@end

static LightGramIOS3GestureReference *LightGramIOS3GestureReferenceForObject(id object)
{
    LightGramIOS3GestureReferenceSentinel *sentinel = objc_getAssociatedObject(object, LightGramIOS3GestureReferenceSentinelKey);
    if (sentinel == nil)
    {
        LightGramIOS3GestureReference *reference = [[LightGramIOS3GestureReference alloc] initWithObject:object];
        sentinel = [[LightGramIOS3GestureReferenceSentinel alloc] initWithReference:reference];
        [reference release];
        objc_setAssociatedObject(object, LightGramIOS3GestureReferenceSentinelKey, sentinel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [sentinel release];
    }
    return [sentinel reference];
}

@implementation UIGestureRecognizer

- (BOOL)lightgramReferencesObject:(id)object
{
    if (object == nil)
        return NO;
    if (_lightgramDelegate == object)
        return YES;
    for (LightGramIOS3GestureTargetAction *targetAction in _lightgramTargetActions)
    {
        if (targetAction->target == object)
            return YES;
    }
    return NO;
}

- (LightGramIOS3GestureReference *)lightgramReferenceForObject:(id)object
{
    for (LightGramIOS3GestureReference *reference in _lightgramReferences)
    {
        if ([reference object] == object)
            return reference;
    }
    return nil;
}

- (void)lightgramTrackReference:(id)object
{
    if (object == nil || object == self || [self lightgramReferenceForObject:object] != nil)
        return;
    LightGramIOS3GestureReference *reference = LightGramIOS3GestureReferenceForObject(object);
    [reference addRecognizer:self];
    if (_lightgramReferences == nil)
        _lightgramReferences = [[NSMutableArray alloc] init];
    [_lightgramReferences addObject:reference];
}

- (void)lightgramUntrackReference:(id)object
{
    if (object == nil || [self lightgramReferencesObject:object])
        return;
    LightGramIOS3GestureReference *reference = [self lightgramReferenceForObject:object];
    if (reference == nil)
        return;
    [reference removeRecognizer:self];
    [_lightgramReferences removeObjectIdenticalTo:reference];
}

- (void)lightgramReferenceInvalidated:(LightGramIOS3GestureReference *)reference
{
    id object = [reference object];
    if (_lightgramDelegate == object)
        _lightgramDelegate = nil;
    for (NSInteger index = (NSInteger)[_lightgramTargetActions count] - 1; index >= 0; index--)
    {
        LightGramIOS3GestureTargetAction *targetAction = [_lightgramTargetActions objectAtIndex:(NSUInteger)index];
        if (targetAction->target == object)
            [_lightgramTargetActions removeObjectAtIndex:(NSUInteger)index];
    }
    [_lightgramReferences removeObjectIdenticalTo:reference];
}

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super init];
    if (self != nil)
    {
        _lightgramTargetActions = [[NSMutableArray alloc] init];
        [self addTarget:target action:action];
        _lightgramState = UIGestureRecognizerStatePossible;
        _lightgramEnabled = YES;
        _lightgramCancelsTouchesInView = YES;
    }
    return self;
}

- (void)dealloc
{
    for (LightGramIOS3GestureReference *reference in _lightgramReferences)
        [reference removeRecognizer:self];
    [_lightgramReferences release];
    [_lightgramTargetActions release];
    [_lightgramTouches release];
    [super dealloc];
}

- (void)addTarget:(id)target action:(SEL)action
{
    if (target == nil || action == NULL)
        return;
    for (LightGramIOS3GestureTargetAction *targetAction in _lightgramTargetActions)
    {
        if (targetAction->target == target && targetAction->action == action)
            return;
    }
    LightGramIOS3GestureTargetAction *targetAction = [[LightGramIOS3GestureTargetAction alloc] initWithTarget:target action:action];
    [_lightgramTargetActions addObject:targetAction];
    [targetAction release];
    [self lightgramTrackReference:target];
}

- (void)removeTarget:(id)target action:(SEL)action
{
    NSMutableArray *removedTargets = [[NSMutableArray alloc] init];
    for (NSInteger index = (NSInteger)[_lightgramTargetActions count] - 1; index >= 0; index--)
    {
        LightGramIOS3GestureTargetAction *targetAction = [_lightgramTargetActions objectAtIndex:(NSUInteger)index];
        if ((target == nil || targetAction->target == target) && (action == NULL || targetAction->action == action))
        {
            [removedTargets addObject:[NSValue valueWithNonretainedObject:targetAction->target]];
            [_lightgramTargetActions removeObjectAtIndex:(NSUInteger)index];
        }
    }
    for (NSValue *removedTarget in removedTargets)
        [self lightgramUntrackReference:[removedTarget nonretainedObjectValue]];
    [removedTargets release];
}

- (id<UIGestureRecognizerDelegate>)delegate { return _lightgramDelegate; }
- (void)setDelegate:(id<UIGestureRecognizerDelegate>)delegate
{
    if (_lightgramDelegate == delegate)
        return;
    id previousDelegate = _lightgramDelegate;
    _lightgramDelegate = delegate;
    [self lightgramTrackReference:delegate];
    [self lightgramUntrackReference:previousDelegate];
}
- (UIGestureRecognizerState)state { return _lightgramState; }
- (UIView *)view { return LightGramIOS3GestureRecognizerView(self); }
- (BOOL)isEnabled { return _lightgramEnabled; }
- (void)setEnabled:(BOOL)enabled
{
    _lightgramEnabled = enabled;
    if (!enabled)
    {
        if (_lightgramState == UIGestureRecognizerStateBegan || _lightgramState == UIGestureRecognizerStateChanged)
            self.state = UIGestureRecognizerStateCancelled;
        [self reset];
    }
}
- (BOOL)cancelsTouchesInView { return _lightgramCancelsTouchesInView; }
- (void)setCancelsTouchesInView:(BOOL)value { _lightgramCancelsTouchesInView = value; }
- (BOOL)delaysTouchesBegan { return _lightgramDelaysTouchesBegan; }
- (void)setDelaysTouchesBegan:(BOOL)value { _lightgramDelaysTouchesBegan = value; }
- (BOOL)delaysTouchesEnded { return _lightgramDelaysTouchesEnded; }
- (void)setDelaysTouchesEnded:(BOOL)value { _lightgramDelaysTouchesEnded = value; }

- (void)setState:(UIGestureRecognizerState)state
{
    if (_lightgramState == state)
        return;
    if (_lightgramState == UIGestureRecognizerStatePossible && state == UIGestureRecognizerStateBegan && [_lightgramDelegate respondsToSelector:@selector(gestureRecognizerShouldBegin:)] && ![_lightgramDelegate gestureRecognizerShouldBegin:self])
        state = UIGestureRecognizerStateFailed;
    _lightgramState = state;
    if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged || state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateRecognized)
    {
        NSArray *targetActions = [[_lightgramTargetActions copy] autorelease];
        for (LightGramIOS3GestureTargetAction *targetAction in targetActions)
        {
            if ([_lightgramTargetActions indexOfObjectIdenticalTo:targetAction] == NSNotFound)
                continue;
            if (targetAction->target != nil && targetAction->action != NULL && [targetAction->target respondsToSelector:targetAction->action])
                ((void (*)(id, SEL, id))objc_msgSend)(targetAction->target, targetAction->action, self);
        }
    }
}

- (CGPoint)locationInView:(UIView *)view
{
    UITouch *touch = [_lightgramTouches anyObject];
    return touch == nil ? CGPointZero : [touch locationInView:view];
}

- (NSUInteger)numberOfTouches { return [_lightgramTouches count]; }

- (CGPoint)locationOfTouch:(NSUInteger)touchIndex inView:(UIView *)view
{
    NSArray *touches = [_lightgramTouches allObjects];
    return touchIndex < [touches count] ? [[touches objectAtIndex:touchIndex] locationInView:view] : CGPointZero;
}

- (void)requireGestureRecognizerToFail:(UIGestureRecognizer *)otherGestureRecognizer { }

- (void)reset
{
    self.state = UIGestureRecognizerStatePossible;
    [_lightgramTouches release];
    _lightgramTouches = nil;
}

- (void)lightgramSetTouches:(NSSet *)touches
{
    if (_lightgramTouches != touches)
    {
        [_lightgramTouches release];
        _lightgramTouches = [touches copy];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event { [self lightgramSetTouches:touches]; }
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event { [self lightgramSetTouches:touches]; }
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event { [self lightgramSetTouches:touches]; }
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event { [self lightgramSetTouches:touches]; self.state = UIGestureRecognizerStateCancelled; }
- (void)lightgramDelayedReset:(id)unused { [self reset]; }

@end

@implementation UIPanGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self != nil)
    {
        _lightgramMinimumNumberOfTouches = 1;
        _lightgramMaximumNumberOfTouches = NSUIntegerMax;
    }
    return self;
}

- (NSUInteger)minimumNumberOfTouches { return _lightgramMinimumNumberOfTouches; }
- (void)setMinimumNumberOfTouches:(NSUInteger)value { _lightgramMinimumNumberOfTouches = value; }
- (NSUInteger)maximumNumberOfTouches { return _lightgramMaximumNumberOfTouches; }
- (void)setMaximumNumberOfTouches:(NSUInteger)value { _lightgramMaximumNumberOfTouches = value; }

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    _lightgramStartLocation = [touch locationInView:self.view];
    _lightgramCurrentLocation = _lightgramStartLocation;
    _lightgramTranslation = CGPointZero;
    _lightgramVelocity = CGPointZero;
    _lightgramLastTimestamp = [touch timestamp];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.view];
    NSTimeInterval timestamp = [touch timestamp];
    NSTimeInterval delta = timestamp - _lightgramLastTimestamp;
    if (delta > 0.0)
        _lightgramVelocity = CGPointMake((location.x - _lightgramCurrentLocation.x) / delta, (location.y - _lightgramCurrentLocation.y) / delta);
    _lightgramCurrentLocation = location;
    _lightgramTranslation = CGPointMake(location.x - _lightgramStartLocation.x, location.y - _lightgramStartLocation.y);
    _lightgramLastTimestamp = timestamp;
    CGFloat distanceSquared = _lightgramTranslation.x * _lightgramTranslation.x + _lightgramTranslation.y * _lightgramTranslation.y;
    if (self.state == UIGestureRecognizerStatePossible && distanceSquared >= 9.0f)
        self.state = UIGestureRecognizerStateBegan;
    else if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged)
        self.state = UIGestureRecognizerStateChanged;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    self.state = (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) ? UIGestureRecognizerStateEnded : UIGestureRecognizerStateFailed;
}

- (CGPoint)translationInView:(UIView *)view { return _lightgramTranslation; }
- (void)setTranslation:(CGPoint)translation inView:(UIView *)view { _lightgramTranslation = translation; _lightgramStartLocation = CGPointMake(_lightgramCurrentLocation.x - translation.x, _lightgramCurrentLocation.y - translation.y); }
- (CGPoint)velocityInView:(UIView *)view { return _lightgramVelocity; }

@end

static CGFloat LightGramIOS3GestureDistance(UITouch *firstTouch, UITouch *secondTouch, UIView *view)
{
    CGPoint first = [firstTouch locationInView:view];
    CGPoint second = [secondTouch locationInView:view];
    CGFloat dx = second.x - first.x;
    CGFloat dy = second.y - first.y;
    return sqrtf(dx * dx + dy * dy);
}

static CGFloat LightGramIOS3GestureAngle(UITouch *firstTouch, UITouch *secondTouch, UIView *view)
{
    CGPoint first = [firstTouch locationInView:view];
    CGPoint second = [secondTouch locationInView:view];
    return atan2f(second.y - first.y, second.x - first.x);
}

static CGFloat LightGramIOS3NormalizedAngleDelta(CGFloat value)
{
    const CGFloat pi = 3.14159265358979323846f;
    while (value > pi)
        value -= pi * 2.0f;
    while (value < -pi)
        value += pi * 2.0f;
    return value;
}

@implementation UIPinchGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self != nil)
        _scale = 1.0f;
    return self;
}

- (CGFloat)scale { return _scale; }
- (void)setScale:(CGFloat)scale { _scale = scale; }
- (CGFloat)velocity { return _lightgramPinchVelocity; }

- (void)lightgramPreparePinchTouches
{
    if (_lightgramPinchFirstTouch != nil && _lightgramPinchSecondTouch != nil)
        return;
    NSArray *touches = [_lightgramTouches allObjects];
    if ([touches count] < 2)
        return;
    _lightgramPinchFirstTouch = [touches objectAtIndex:0];
    _lightgramPinchSecondTouch = [touches objectAtIndex:1];
    _lightgramPreviousDistance = LightGramIOS3GestureDistance(_lightgramPinchFirstTouch, _lightgramPinchSecondTouch, self.view);
    _lightgramPinchLastTimestamp = MAX([_lightgramPinchFirstTouch timestamp], [_lightgramPinchSecondTouch timestamp]);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    [self lightgramPreparePinchTouches];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    [self lightgramPreparePinchTouches];
    if (_lightgramPinchFirstTouch == nil || _lightgramPinchSecondTouch == nil || _lightgramPreviousDistance <= 0.0f)
        return;

    CGFloat distance = LightGramIOS3GestureDistance(_lightgramPinchFirstTouch, _lightgramPinchSecondTouch, self.view);
    NSTimeInterval timestamp = MAX([_lightgramPinchFirstTouch timestamp], [_lightgramPinchSecondTouch timestamp]);
    NSTimeInterval deltaTime = timestamp - _lightgramPinchLastTimestamp;
    CGFloat relativeScale = distance / _lightgramPreviousDistance;
    _scale *= relativeScale;
    _lightgramPinchVelocity = deltaTime > 0.0 ? (relativeScale - 1.0f) / deltaTime : 0.0f;
    _lightgramPreviousDistance = distance;
    _lightgramPinchLastTimestamp = timestamp;

    if (self.state == UIGestureRecognizerStatePossible)
        self.state = UIGestureRecognizerStateBegan;
    else if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged)
        self.state = UIGestureRecognizerStateChanged;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    self.state = (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) ? UIGestureRecognizerStateEnded : UIGestureRecognizerStateFailed;
    _lightgramPinchFirstTouch = nil;
    _lightgramPinchSecondTouch = nil;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    _lightgramPinchFirstTouch = nil;
    _lightgramPinchSecondTouch = nil;
}

- (CGPoint)locationInView:(UIView *)view
{
    if (_lightgramPinchFirstTouch == nil || _lightgramPinchSecondTouch == nil)
        return [super locationInView:view];
    CGPoint first = [_lightgramPinchFirstTouch locationInView:view];
    CGPoint second = [_lightgramPinchSecondTouch locationInView:view];
    return CGPointMake((first.x + second.x) * 0.5f, (first.y + second.y) * 0.5f);
}

- (void)reset
{
    [super reset];
    _scale = 1.0f;
    _lightgramPinchVelocity = 0.0f;
    _lightgramPreviousDistance = 0.0f;
    _lightgramPinchLastTimestamp = 0.0;
    _lightgramPinchFirstTouch = nil;
    _lightgramPinchSecondTouch = nil;
}

@end

@implementation UIRotationGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    return self;
}

- (CGFloat)rotation { return _rotation; }
- (void)setRotation:(CGFloat)rotation { _rotation = rotation; }
- (CGFloat)velocity { return _lightgramRotationVelocity; }

- (void)lightgramPrepareRotationTouches
{
    if (_lightgramRotationFirstTouch != nil && _lightgramRotationSecondTouch != nil)
        return;
    NSArray *touches = [_lightgramTouches allObjects];
    if ([touches count] < 2)
        return;
    _lightgramRotationFirstTouch = [touches objectAtIndex:0];
    _lightgramRotationSecondTouch = [touches objectAtIndex:1];
    _lightgramPreviousAngle = LightGramIOS3GestureAngle(_lightgramRotationFirstTouch, _lightgramRotationSecondTouch, self.view);
    _lightgramRotationLastTimestamp = MAX([_lightgramRotationFirstTouch timestamp], [_lightgramRotationSecondTouch timestamp]);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    [self lightgramPrepareRotationTouches];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    [self lightgramPrepareRotationTouches];
    if (_lightgramRotationFirstTouch == nil || _lightgramRotationSecondTouch == nil)
        return;

    CGFloat angle = LightGramIOS3GestureAngle(_lightgramRotationFirstTouch, _lightgramRotationSecondTouch, self.view);
    CGFloat delta = LightGramIOS3NormalizedAngleDelta(angle - _lightgramPreviousAngle);
    NSTimeInterval timestamp = MAX([_lightgramRotationFirstTouch timestamp], [_lightgramRotationSecondTouch timestamp]);
    NSTimeInterval deltaTime = timestamp - _lightgramRotationLastTimestamp;
    _rotation += delta;
    _lightgramRotationVelocity = deltaTime > 0.0 ? delta / deltaTime : 0.0f;
    _lightgramPreviousAngle = angle;
    _lightgramRotationLastTimestamp = timestamp;

    if (self.state == UIGestureRecognizerStatePossible)
    {
        if (fabsf(_rotation) >= 0.01f)
            self.state = UIGestureRecognizerStateBegan;
    }
    else if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged)
    {
        self.state = UIGestureRecognizerStateChanged;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    self.state = (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) ? UIGestureRecognizerStateEnded : UIGestureRecognizerStateFailed;
    _lightgramRotationFirstTouch = nil;
    _lightgramRotationSecondTouch = nil;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    _lightgramRotationFirstTouch = nil;
    _lightgramRotationSecondTouch = nil;
}

- (CGPoint)locationInView:(UIView *)view
{
    if (_lightgramRotationFirstTouch == nil || _lightgramRotationSecondTouch == nil)
        return [super locationInView:view];
    CGPoint first = [_lightgramRotationFirstTouch locationInView:view];
    CGPoint second = [_lightgramRotationSecondTouch locationInView:view];
    return CGPointMake((first.x + second.x) * 0.5f, (first.y + second.y) * 0.5f);
}

- (void)reset
{
    [super reset];
    _rotation = 0.0f;
    _lightgramRotationVelocity = 0.0f;
    _lightgramPreviousAngle = 0.0f;
    _lightgramRotationLastTimestamp = 0.0;
    _lightgramRotationFirstTouch = nil;
    _lightgramRotationSecondTouch = nil;
}

@end

@implementation UISwipeGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self != nil)
        _lightgramDirection = UISwipeGestureRecognizerDirectionRight;
    return self;
}

- (UISwipeGestureRecognizerDirection)direction
{
    return _lightgramDirection;
}

- (void)setDirection:(UISwipeGestureRecognizerDirection)direction
{
    _lightgramDirection = direction;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    _lightgramSwipeStartLocation = touch == nil ? CGPointZero : [touch locationInView:self.view];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    if (touch == nil)
    {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }

    CGPoint endLocation = [touch locationInView:self.view];
    CGFloat dx = endLocation.x - _lightgramSwipeStartLocation.x;
    CGFloat dy = endLocation.y - _lightgramSwipeStartLocation.y;
    CGFloat absoluteX = dx < 0.0f ? -dx : dx;
    CGFloat absoluteY = dy < 0.0f ? -dy : dy;
    UISwipeGestureRecognizerDirection detectedDirection = 0;

    if (MAX(absoluteX, absoluteY) >= 24.0f)
    {
        if (absoluteX >= absoluteY)
            detectedDirection = dx >= 0.0f ? UISwipeGestureRecognizerDirectionRight : UISwipeGestureRecognizerDirectionLeft;
        else
            detectedDirection = dy >= 0.0f ? UISwipeGestureRecognizerDirectionDown : UISwipeGestureRecognizerDirectionUp;
    }

    self.state = (detectedDirection != 0 && (_lightgramDirection & detectedDirection) != 0) ? UIGestureRecognizerStateRecognized : UIGestureRecognizerStateFailed;
}

@end

@implementation UITapGestureRecognizer
@synthesize numberOfTapsRequired = _numberOfTapsRequired;
@synthesize numberOfTouchesRequired = _numberOfTouchesRequired;
- (instancetype)initWithTarget:(id)target action:(SEL)action { self = [super initWithTarget:target action:action]; if (self != nil) { _numberOfTapsRequired = 1; _numberOfTouchesRequired = 1; } return self; }
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event { [super touchesEnded:touches withEvent:event]; self.state = UIGestureRecognizerStateRecognized; }
@end

@implementation UILongPressGestureRecognizer
@synthesize numberOfTapsRequired = _numberOfTapsRequired;
@synthesize numberOfTouchesRequired = _numberOfTouchesRequired;
@synthesize minimumPressDuration = _minimumPressDuration;
@synthesize allowableMovement = _allowableMovement;
- (instancetype)initWithTarget:(id)target action:(SEL)action { self = [super initWithTarget:target action:action]; if (self != nil) { _numberOfTouchesRequired = 1; _minimumPressDuration = 0.5; _allowableMovement = 10.0f; } return self; }
@end

@implementation UIView (LightGramIOS3GestureCompatibility)

- (NSArray *)gestureRecognizers
{
    LightGramIOS3GestureRecognizerRegistry *registry = LightGramIOS3GestureRecognizerRegistryForView(self, NO);
    if (registry == nil)
        return [NSArray array];
    return [[[registry recognizerSnapshot] copy] autorelease];
}

- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == nil)
        return;

    [gestureRecognizer retain];
    UIView *currentView = LightGramIOS3GestureRecognizerView(gestureRecognizer);
    if (currentView != nil && currentView != self)
        [currentView removeGestureRecognizer:gestureRecognizer];

    LightGramIOS3GestureRecognizerRegistry *registry = LightGramIOS3GestureRecognizerRegistryForView(self, YES);
    [registry addRecognizer:gestureRecognizer];
    LightGramIOS3SetGestureRecognizerView(gestureRecognizer, self);
    [gestureRecognizer release];
}

- (void)removeGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == nil)
        return;

    [gestureRecognizer retain];
    LightGramIOS3GestureRecognizerRegistry *registry = LightGramIOS3GestureRecognizerRegistryForView(self, NO);

    if (LightGramIOS3GestureRecognizerView(gestureRecognizer) == self)
        LightGramIOS3SetGestureRecognizerView(gestureRecognizer, nil);

    [registry removeRecognizer:gestureRecognizer];

    if (registry != nil && [[registry recognizerSnapshot] count] == 0)
        objc_setAssociatedObject(self, LightGramIOS3GestureRecognizerRegistryKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [gestureRecognizer release];
}

@end

static void LightGramIOS3DispatchGestureTouches(UIView *view, NSSet *touches, UIEvent *event)
{
    if (view == nil || [touches count] == 0)
        return;

    BOOL hasBegan = NO;
    BOOL hasMoved = NO;
    BOOL hasEnded = NO;
    BOOL hasCancelled = NO;
    for (UITouch *touch in touches)
    {
        switch ([touch phase])
        {
            case UITouchPhaseBegan: hasBegan = YES; break;
            case UITouchPhaseMoved: hasMoved = YES; break;
            case UITouchPhaseEnded: hasEnded = YES; break;
            case UITouchPhaseCancelled: hasCancelled = YES; break;
            default: break;
        }
    }

    for (UIView *current = view; current != nil; current = [current superview])
    {
        LightGramIOS3GestureRecognizerRegistry *registry = LightGramIOS3GestureRecognizerRegistryForView(current, NO);
        if (registry == nil)
            continue;

        NSArray *recognizers = [[registry recognizerSnapshot] retain];
        for (UIGestureRecognizer *recognizer in recognizers)
        {
            if (![recognizer isKindOfClass:[UIGestureRecognizer class]] || ![recognizer isEnabled])
                continue;

            BOOL accepted = YES;
            id<UIGestureRecognizerDelegate> delegate = recognizer.delegate;
            if ([delegate respondsToSelector:@selector(gestureRecognizer:shouldReceiveTouch:)])
            {
                for (UITouch *touch in touches)
                {
                    if (![delegate gestureRecognizer:recognizer shouldReceiveTouch:touch])
                    {
                        accepted = NO;
                        break;
                    }
                }
            }
            if (!accepted)
                continue;

            if (hasCancelled)
                [recognizer touchesCancelled:touches withEvent:event];
            else if (hasEnded)
                [recognizer touchesEnded:touches withEvent:event];
            else if (hasMoved)
                [recognizer touchesMoved:touches withEvent:event];
            else if (hasBegan)
                [recognizer touchesBegan:touches withEvent:event];

            if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateRecognized || recognizer.state == UIGestureRecognizerStateFailed || recognizer.state == UIGestureRecognizerStateCancelled)
            {
                if ([recognizer respondsToSelector:@selector(lightgramDelayedReset:)])
                    [recognizer performSelector:@selector(lightgramDelayedReset:) withObject:nil afterDelay:0.0];
                else if ([recognizer respondsToSelector:@selector(reset)])
                    [recognizer performSelector:@selector(reset) withObject:nil afterDelay:0.0];
            }
        }
        [recognizers release];
    }
}

@implementation UIWindow (LightGramIOS3GestureEventCompatibility)

+ (void)load
{
    Method original = class_getInstanceMethod(self, @selector(sendEvent:));
    Method replacement = class_getInstanceMethod(self, @selector(lightgram_sendEvent:));
    if (original != NULL && replacement != NULL)
        method_exchangeImplementations(original, replacement);
}

- (void)lightgram_sendEvent:(UIEvent *)event
{
    NSSet *allTouches = [event allTouches];
    NSUInteger touchCount = [allTouches count];

    if (touchCount == 1)
    {
        UITouch *touch = [allTouches anyObject];
        LightGramIOS3DispatchGestureTouches([touch view], allTouches, event);
    }
    else if (touchCount > 1)
    {
        NSMutableDictionary *touchesByView = [NSMutableDictionary dictionary];
        for (UITouch *touch in allTouches)
        {
            UIView *view = [touch view];
            if (view == nil)
                continue;
            NSValue *key = [NSValue valueWithNonretainedObject:view];
            NSMutableSet *touches = [touchesByView objectForKey:key];
            if (touches == nil)
            {
                touches = [NSMutableSet set];
                [touchesByView setObject:touches forKey:key];
            }
            [touches addObject:touch];
        }

        for (NSValue *key in touchesByView)
            LightGramIOS3DispatchGestureTouches([key nonretainedObjectValue], [touchesByView objectForKey:key], event);
    }

    [self lightgram_sendEvent:event];
}

@end


@implementation UIView (LightGramIOS3AnimationCompatibilityFallback)

+ (void)lightgramIOS3Fallback_performWithoutAnimation:(void (^)(void))actionsWithoutAnimation
{
    BOOL animationsEnabled = [self areAnimationsEnabled];
    [self setAnimationsEnabled:NO];
    @try
    {
        if (actionsWithoutAnimation != nil)
            actionsWithoutAnimation();
    }
    @finally
    {
        [self setAnimationsEnabled:animationsEnabled];
    }
}

+ (void)lightgramIOS3Fallback_animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
{
    [self beginAnimations:nil context:NULL];
    [self setAnimationDuration:duration];
    if (animations != nil)
        animations();
    [self commitAnimations];
}

+ (void)lightgramIOS3Fallback_animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(BOOL))completion
{
    [self animateWithDuration:duration delay:0.0 options:0 animations:animations completion:completion];
}

+ (void)lightgramIOS3Fallback_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(NSUInteger)options animations:(void (^)(void))animations completion:(void (^)(BOOL))completion
{
    [self beginAnimations:nil context:NULL];
    [self setAnimationDuration:duration];
    [self setAnimationDelay:delay];
    [self setAnimationBeginsFromCurrentState:(options & (1UL << 2)) != 0];
    [self setAnimationRepeatAutoreverses:(options & (1UL << 4)) != 0];
    if ((options & (1UL << 3)) != 0)
        [self setAnimationRepeatCount:1.0e30f];

    NSUInteger curve = (options >> 16) & 3U;
    switch (curve)
    {
        case 1: [self setAnimationCurve:UIViewAnimationCurveEaseIn]; break;
        case 2: [self setAnimationCurve:UIViewAnimationCurveEaseOut]; break;
        case 3: [self setAnimationCurve:UIViewAnimationCurveLinear]; break;
        default: [self setAnimationCurve:UIViewAnimationCurveEaseInOut]; break;
    }

    if (animations != nil)
        animations();
    [self commitAnimations];

    if (completion != nil && (options & (1UL << 3)) == 0)
    {
        LightGramIOS3AnimationCompletionTarget *target = [[LightGramIOS3AnimationCompletionTarget alloc] initWithCompletion:completion];
        [NSTimer scheduledTimerWithTimeInterval:MAX(0.0, delay + duration) target:target selector:@selector(fire:) userInfo:nil repeats:NO];
    }
}

+ (void)lightgramIOS3Fallback_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)__unused dampingRatio initialSpringVelocity:(CGFloat)__unused velocity options:(NSUInteger)options animations:(void (^)(void))animations completion:(void (^)(BOOL))completion
{
    [self animateWithDuration:duration delay:delay options:options animations:animations completion:completion];
}

+ (void)lightgramIOS3Fallback_animateKeyframesWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(NSUInteger)options animations:(void (^)(void))animations completion:(void (^)(BOOL))completion
{
    NSMutableArray *stack = LightGramIOS3KeyframeAnimationStack();
    NSDictionary *context = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithDouble:duration], @"duration",
        [NSNumber numberWithDouble:delay], @"delay",
        [NSNumber numberWithUnsignedInteger:options], @"options",
        nil];
    [stack addObject:context];
    @try
    {
        if (animations != nil)
            animations();
    }
    @finally
    {
        [stack removeLastObject];
    }

    if (completion != nil)
    {
        LightGramIOS3AnimationCompletionTarget *target = [[LightGramIOS3AnimationCompletionTarget alloc] initWithCompletion:completion];
        [NSTimer scheduledTimerWithTimeInterval:MAX(0.0, delay + duration) target:target selector:@selector(fire:) userInfo:nil repeats:NO];
    }
}

+ (void)lightgramIOS3Fallback_addKeyframeWithRelativeStartTime:(double)frameStartTime relativeDuration:(double)frameDuration animations:(void (^)(void))animations
{
    NSArray *stack = LightGramIOS3KeyframeAnimationStack();
    NSDictionary *context = [stack lastObject];
    if (context == nil)
    {
        if (animations != nil)
            animations();
        return;
    }

    NSTimeInterval duration = [[context objectForKey:@"duration"] doubleValue];
    NSTimeInterval delay = [[context objectForKey:@"delay"] doubleValue];
    NSUInteger options = [[context objectForKey:@"options"] unsignedIntegerValue];
    [self animateWithDuration:MAX(0.0, duration * frameDuration) delay:MAX(0.0, delay + duration * frameStartTime) options:options animations:animations completion:nil];
}

+ (void)lightgramIOS3Fallback_transitionWithView:(UIView *)view duration:(NSTimeInterval)duration options:(NSUInteger)options animations:(void (^)(void))animations completion:(void (^)(BOOL))completion
{
    [self beginAnimations:nil context:NULL];
    [self setAnimationDuration:duration];
    [self setAnimationBeginsFromCurrentState:(options & (1UL << 2)) != 0];

    NSUInteger curve = (options >> 16) & 3U;
    switch (curve)
    {
        case 1: [self setAnimationCurve:UIViewAnimationCurveEaseIn]; break;
        case 2: [self setAnimationCurve:UIViewAnimationCurveEaseOut]; break;
        case 3: [self setAnimationCurve:UIViewAnimationCurveLinear]; break;
        default: [self setAnimationCurve:UIViewAnimationCurveEaseInOut]; break;
    }

    NSUInteger transition = (options >> 20) & 7U;
    switch (transition)
    {
        case 1: [self setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:view cache:YES]; break;
        case 2: [self setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:view cache:YES]; break;
        case 3: [self setAnimationTransition:UIViewAnimationTransitionCurlUp forView:view cache:YES]; break;
        case 4: [self setAnimationTransition:UIViewAnimationTransitionCurlDown forView:view cache:YES]; break;
        default: break;
    }

    if (animations != nil)
        animations();
    [self commitAnimations];

    if (completion != nil)
    {
        LightGramIOS3AnimationCompletionTarget *target = [[LightGramIOS3AnimationCompletionTarget alloc] initWithCompletion:completion];
        [NSTimer scheduledTimerWithTimeInterval:MAX(0.0, duration) target:target selector:@selector(fire:) userInfo:nil repeats:NO];
    }
}

@end


static const void *LightGramIOS3ChildViewControllersKey = &LightGramIOS3ChildViewControllersKey;
static const void *LightGramIOS3ParentViewControllerKey = &LightGramIOS3ParentViewControllerKey;
static const void *LightGramIOS3AppearanceTransitionStackKey = &LightGramIOS3AppearanceTransitionStackKey;
static BOOL LightGramIOS3HasOriginalParentViewController = NO;

@interface UIViewController (LightGramIOS3ContainmentCompatibilityImplementation)
- (void)removeChildViewController:(UIViewController *)childController;
- (NSArray *)lightgramIOS3_childViewControllers;
- (void)lightgramIOS3_addChildViewController:(UIViewController *)childController;
- (void)lightgramIOS3_removeFromParentViewController;
- (void)lightgramIOS3_willMoveToParentViewController:(UIViewController *)parent;
- (void)lightgramIOS3_didMoveToParentViewController:(UIViewController *)parent;
- (void)lightgramIOS3_beginAppearanceTransition:(BOOL)isAppearing animated:(BOOL)animated;
- (void)lightgramIOS3_endAppearanceTransition;
@end

@implementation UIViewController (LightGramIOS3ContainmentCompatibility)

+ (void)load
{
    Method original = class_getInstanceMethod(self, @selector(parentViewController));
    Method replacement = class_getInstanceMethod(self, @selector(lightgramIOS3_parentViewController));
    if (original != NULL && replacement != NULL)
    {
        LightGramIOS3HasOriginalParentViewController = YES;
        method_exchangeImplementations(original, replacement);
    }
    else if (replacement != NULL)
        class_addMethod(self, @selector(parentViewController), method_getImplementation(replacement), method_getTypeEncoding(replacement));

    SEL selectors[] = {
        @selector(childViewControllers),
        @selector(addChildViewController:),
        @selector(removeFromParentViewController),
        @selector(willMoveToParentViewController:),
        @selector(didMoveToParentViewController:),
        @selector(beginAppearanceTransition:animated:),
        @selector(endAppearanceTransition)
    };
    SEL replacements[] = {
        @selector(lightgramIOS3_childViewControllers),
        @selector(lightgramIOS3_addChildViewController:),
        @selector(lightgramIOS3_removeFromParentViewController),
        @selector(lightgramIOS3_willMoveToParentViewController:),
        @selector(lightgramIOS3_didMoveToParentViewController:),
        @selector(lightgramIOS3_beginAppearanceTransition:animated:),
        @selector(lightgramIOS3_endAppearanceTransition)
    };

    for (NSUInteger index = 0; index < sizeof(selectors) / sizeof(selectors[0]); index++)
    {
        if (class_getInstanceMethod(self, selectors[index]) != NULL)
            continue;
        Method method = class_getInstanceMethod(self, replacements[index]);
        if (method != NULL)
            class_addMethod(self, selectors[index], method_getImplementation(method), method_getTypeEncoding(method));
    }
}

- (UIViewController *)lightgramIOS3_parentViewController
{
    UIViewController *parent = objc_getAssociatedObject(self, LightGramIOS3ParentViewControllerKey);
    if (parent != nil)
        return parent;
    if (LightGramIOS3HasOriginalParentViewController)
        return [self lightgramIOS3_parentViewController];
    return nil;
}

- (NSArray *)lightgramIOS3_childViewControllers
{
    NSMutableArray *children = objc_getAssociatedObject(self, LightGramIOS3ChildViewControllersKey);
    if (children != nil)
        return [[children copy] autorelease];
    if ([self isKindOfClass:[UINavigationController class]])
        return [(UINavigationController *)self viewControllers];
    if ([self isKindOfClass:[UITabBarController class]])
        return [(UITabBarController *)self viewControllers];
    return [NSArray array];
}

- (void)lightgramIOS3_addChildViewController:(UIViewController *)childController
{
    if (childController == nil || childController == self)
        return;

    UIViewController *oldParent = objc_getAssociatedObject(childController, LightGramIOS3ParentViewControllerKey);
    if (oldParent != nil && oldParent != self)
        [childController removeFromParentViewController];

    NSMutableArray *children = objc_getAssociatedObject(self, LightGramIOS3ChildViewControllersKey);
    if (children == nil)
    {
        children = [NSMutableArray array];
        objc_setAssociatedObject(self, LightGramIOS3ChildViewControllersKey, children, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (![children containsObject:childController])
    {
        [childController willMoveToParentViewController:self];
        [children addObject:childController];
        objc_setAssociatedObject(childController, LightGramIOS3ParentViewControllerKey, self, OBJC_ASSOCIATION_ASSIGN);
        [childController didMoveToParentViewController:self];
    }
}

- (void)lightgramIOS3_removeFromParentViewController
{
    UIViewController *parent = [self parentViewController];
    if (parent == nil)
        return;
    [self willMoveToParentViewController:nil];
    NSMutableArray *children = objc_getAssociatedObject(parent, LightGramIOS3ChildViewControllersKey);
    [children removeObjectIdenticalTo:self];
    if ([parent respondsToSelector:@selector(removeChildViewController:)])
        [parent removeChildViewController:self];
    objc_setAssociatedObject(self, LightGramIOS3ParentViewControllerKey, nil, OBJC_ASSOCIATION_ASSIGN);
    [self didMoveToParentViewController:nil];
}

- (void)lightgramIOS3_willMoveToParentViewController:(UIViewController *)parent
{
}

- (void)lightgramIOS3_didMoveToParentViewController:(UIViewController *)parent
{
}

- (void)lightgramIOS3_beginAppearanceTransition:(BOOL)isAppearing animated:(BOOL)animated
{
    NSMutableArray *stack = objc_getAssociatedObject(self, LightGramIOS3AppearanceTransitionStackKey);
    if (stack == nil)
    {
        stack = [NSMutableArray array];
        objc_setAssociatedObject(self, LightGramIOS3AppearanceTransitionStackKey, stack, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    [stack addObject:[NSArray arrayWithObjects:[NSNumber numberWithBool:isAppearing], [NSNumber numberWithBool:animated], nil]];

    if (isAppearing)
        [self viewWillAppear:animated];
    else
        [self viewWillDisappear:animated];
}

- (void)lightgramIOS3_endAppearanceTransition
{
    NSMutableArray *stack = objc_getAssociatedObject(self, LightGramIOS3AppearanceTransitionStackKey);
    if ([stack count] == 0)
        return;

    NSArray *transition = [stack lastObject];
    BOOL isAppearing = [[transition objectAtIndex:0] boolValue];
    BOOL animated = [[transition objectAtIndex:1] boolValue];
    [stack removeLastObject];

    if (isAppearing)
        [self viewDidAppear:animated];
    else
        [self viewDidDisappear:animated];

    if ([stack count] == 0)
        objc_setAssociatedObject(self, LightGramIOS3AppearanceTransitionStackKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

static const void *LightGramIOS3PopoverContentSizeKey = &LightGramIOS3PopoverContentSizeKey;

@implementation UIViewController (LightGramIOS3PopoverCompatibilityFallback)

- (CGSize)lightgramIOS3Fallback_contentSizeForViewInPopover
{
    NSValue *value = objc_getAssociatedObject(self, LightGramIOS3PopoverContentSizeKey);
    return value == nil ? CGSizeZero : [value CGSizeValue];
}
- (void)lightgramIOS3Fallback_setContentSizeForViewInPopover:(CGSize)size
{
    objc_setAssociatedObject(self, LightGramIOS3PopoverContentSizeKey, [NSValue valueWithCGSize:size], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UIPopoverBackgroundView
+ (CGFloat)arrowHeight { return 0.0f; }
+ (CGFloat)arrowBase { return 0.0f; }
+ (UIEdgeInsets)contentViewInsets { return UIEdgeInsetsZero; }
- (CGFloat)arrowOffset { return 0.0f; }
- (void)setArrowOffset:(CGFloat)value { }
- (UIPopoverArrowDirection)arrowDirection { return UIPopoverArrowDirectionUnknown; }
- (void)setArrowDirection:(UIPopoverArrowDirection)value { }
+ (BOOL)wantsDefaultContentAppearance { return YES; }
@end

@implementation UIPopoverController

- (instancetype)initWithContentViewController:(UIViewController *)viewController
{
    self = [super init];
    if (self != nil)
        _lightgramContentViewController = [viewController retain];
    return self;
}

- (void)dealloc
{
    [_lightgramContentViewController release];
    [super dealloc];
}

- (UIViewController *)contentViewController { return _lightgramContentViewController; }
- (void)setContentViewController:(UIViewController *)controller { if (_lightgramContentViewController != controller) { [_lightgramContentViewController release]; _lightgramContentViewController = [controller retain]; } }
- (id<UIPopoverControllerDelegate>)delegate { return _lightgramPopoverDelegate; }
- (void)setDelegate:(id<UIPopoverControllerDelegate>)delegate { _lightgramPopoverDelegate = delegate; }
- (CGSize)popoverContentSize { return _lightgramPopoverContentSize; }
- (void)setPopoverContentSize:(CGSize)size { _lightgramPopoverContentSize = size; }
- (void)setPopoverContentSize:(CGSize)size animated:(BOOL)animated { _lightgramPopoverContentSize = size; }
- (Class)popoverBackgroundViewClass { return Nil; }
- (void)setPopoverBackgroundViewClass:(Class)value { }

- (void)presentPopoverFromRect:(CGRect)rect inView:(UIView *)view permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections animated:(BOOL)animated
{
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    if (window != nil && _lightgramContentViewController != nil)
    {
        UIView *contentView = [_lightgramContentViewController view];
        if (!CGSizeEqualToSize(_lightgramPopoverContentSize, CGSizeZero))
            contentView.frame = CGRectMake(0.0f, 0.0f, _lightgramPopoverContentSize.width, _lightgramPopoverContentSize.height);
        contentView.center = CGPointMake(CGRectGetMidX(window.bounds), CGRectGetMidY(window.bounds));
        [window addSubview:contentView];
    }
}

- (void)presentPopoverFromBarButtonItem:(UIBarButtonItem *)item permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections animated:(BOOL)animated
{
    [self presentPopoverFromRect:CGRectZero inView:nil permittedArrowDirections:arrowDirections animated:animated];
}

- (void)dismissPopoverAnimated:(BOOL)animated
{
    [[_lightgramContentViewController view] removeFromSuperview];
    if ([_lightgramPopoverDelegate respondsToSelector:@selector(popoverControllerDidDismissPopover:)])
        [_lightgramPopoverDelegate popoverControllerDidDismissPopover:self];
}

@end

#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@implementation UINib

+ (UINib *)nibWithNibName:(NSString *)name bundle:(NSBundle *)bundle
{
    UINib *nib = [[[self alloc] init] autorelease];
    nib->_name = [name copy];
    nib->_bundle = [bundle retain];
    return nib;
}

- (void)dealloc
{
    [_name release];
    [_bundle release];
    [super dealloc];
}

- (NSArray *)instantiateWithOwner:(id)owner options:(NSDictionary *)options
{
    NSBundle *bundle = _bundle == nil ? [NSBundle mainBundle] : _bundle;
    return [bundle loadNibNamed:_name owner:owner options:options];
}

@end
#endif

void (*LightGramIOS3OffMainGraphicsHandler)(const void *caller) = NULL;

void UIGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale)
{
    if (LightGramIOS3OffMainGraphicsHandler != NULL && !pthread_main_np())
        LightGramIOS3OffMainGraphicsHandler(__builtin_return_address(0));
    UIGraphicsBeginImageContext(size);
}

static UIImage *LightGramIOS3ImageWithCGImageOrientation(CGImageRef cgImage, UIImageOrientation orientation)
{
    if (cgImage == NULL)
        return nil;

    CGFloat width = (CGFloat)CGImageGetWidth(cgImage);
    CGFloat height = (CGFloat)CGImageGetHeight(cgImage);
    BOOL sideward = orientation == UIImageOrientationLeft || orientation == UIImageOrientationRight || orientation == UIImageOrientationLeftMirrored || orientation == UIImageOrientationRightMirrored;
    CGSize outputSize = sideward ? CGSizeMake(height, width) : CGSizeMake(width, height);

    UIGraphicsBeginImageContext(outputSize);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGAffineTransform transform = CGAffineTransformIdentity;

    switch (orientation)
    {
        case UIImageOrientationUpMirrored:
            transform = CGAffineTransformMake(-1.0f, 0.0f, 0.0f, 1.0f, width, 0.0f);
            break;
        case UIImageOrientationDown:
            transform = CGAffineTransformMake(-1.0f, 0.0f, 0.0f, -1.0f, width, height);
            break;
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformMake(1.0f, 0.0f, 0.0f, -1.0f, 0.0f, height);
            break;
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformMake(0.0f, 1.0f, 1.0f, 0.0f, 0.0f, 0.0f);
            break;
        case UIImageOrientationRight:
            transform = CGAffineTransformMake(0.0f, 1.0f, -1.0f, 0.0f, height, 0.0f);
            break;
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformMake(0.0f, -1.0f, -1.0f, 0.0f, height, width);
            break;
        case UIImageOrientationLeft:
            transform = CGAffineTransformMake(0.0f, -1.0f, 1.0f, 0.0f, 0.0f, width);
            break;
        case UIImageOrientationUp:
        default:
            break;
    }

    CGContextConcatCTM(context, transform);
    UIImage *sourceImage = [UIImage imageWithCGImage:cgImage];
    [sourceImage drawInRect:CGRectMake(0.0f, 0.0f, width, height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@implementation UIImage (LightGramIOS3ScaleCompatibilityFallback)

- (CGFloat)lightgramIOS3Fallback_scale
{
    return 1.0f;
}

+ (UIImage *)lightgramIOS3Fallback_imageWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation
{
    return [[[self alloc] initWithCGImage:cgImage scale:scale orientation:orientation] autorelease];
}

- (instancetype)lightgramIOS3Fallback_initWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation
{
    if (cgImage == NULL)
    {
        [self release];
        return nil;
    }

    CGFloat normalizedScale = scale > 0.0f ? scale : 1.0f;
    if (normalizedScale == 1.0f && orientation == UIImageOrientationUp)
        return [self initWithCGImage:cgImage];

    UIImage *image = orientation == UIImageOrientationUp ? [UIImage imageWithCGImage:cgImage] : LightGramIOS3ImageWithCGImageOrientation(cgImage, orientation);
    if (image == nil || image.CGImage == NULL)
    {
        [self release];
        return nil;
    }

    if (normalizedScale == 1.0f)
        return [self initWithCGImage:image.CGImage];

    CGSize targetSize = CGSizeMake(MAX(1.0f, (CGFloat)CGImageGetWidth(image.CGImage) / normalizedScale), MAX(1.0f, (CGFloat)CGImageGetHeight(image.CGImage) / normalizedScale));
    UIGraphicsBeginImageContext(targetSize);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context != NULL)
        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    [image drawInRect:CGRectMake(0.0f, 0.0f, targetSize.width, targetSize.height)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (scaledImage == nil || scaledImage.CGImage == NULL)
    {
        [self release];
        return nil;
    }
    return [self initWithCGImage:scaledImage.CGImage];
}

- (UIImage *)lightgramIOS3Fallback_resizableImageWithCapInsets:(UIEdgeInsets)capInsets
{
    NSInteger left = (NSInteger)floor(capInsets.left);
    NSInteger top = (NSInteger)floor(capInsets.top);
    NSInteger maxLeft = MAX(0, (NSInteger)floor(self.size.width) - 1);
    NSInteger maxTop = MAX(0, (NSInteger)floor(self.size.height) - 1);
    left = MAX(0, MIN(left, maxLeft));
    top = MAX(0, MIN(top, maxTop));
    return [self stretchableImageWithLeftCapWidth:left topCapHeight:top];
}

- (UIEdgeInsets)lightgramIOS3Fallback_capInsets
{
    CGFloat left = self.leftCapWidth;
    CGFloat top = self.topCapHeight;
    CGFloat right = left > 0.0f ? MAX(0.0f, self.size.width - left - 1.0f) : 0.0f;
    CGFloat bottom = top > 0.0f ? MAX(0.0f, self.size.height - top - 1.0f) : 0.0f;
    return UIEdgeInsetsMake(top, left, bottom, right);
}

@end

@implementation UIScreen (LightGramIOS3ScaleCompatibilityFallback)

- (CGFloat)lightgramIOS3Fallback_scale
{
    return 1.0f;
}

@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@implementation UIDevice (LightGramIOS3InterfaceIdiomCompatibilityFallback)

- (UIUserInterfaceIdiom)lightgramIOS3Fallback_userInterfaceIdiom
{
    return UIUserInterfaceIdiomPhone;
}

@end

static char LightGramIOS3ModalPresentationStyleKey;
static char LightGramIOS3PresentingViewControllerKey;

@implementation UIViewController (LightGramIOS3PresentationCompatibilityFallback)

- (void)lightgramIOS3Fallback_setModalPresentationStyle:(UIModalPresentationStyle)modalPresentationStyle
{
    objc_setAssociatedObject(self, &LightGramIOS3ModalPresentationStyleKey, [NSNumber numberWithInteger:modalPresentationStyle], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIModalPresentationStyle)lightgramIOS3Fallback_modalPresentationStyle
{
    NSNumber *value = objc_getAssociatedObject(self, &LightGramIOS3ModalPresentationStyleKey);
    return value == nil ? UIModalPresentationFullScreen : (UIModalPresentationStyle)[value integerValue];
}

- (UIViewController *)lightgramIOS3Fallback_presentedViewController
{
    return self.modalViewController;
}

- (UIViewController *)lightgramIOS3Fallback_presentingViewController
{
    UIViewController *presenter = objc_getAssociatedObject(self, &LightGramIOS3PresentingViewControllerKey);
    if (presenter != nil)
        return presenter;

    UIViewController *parent = self.parentViewController;
    while (parent != nil && parent != self)
    {
        presenter = objc_getAssociatedObject(parent, &LightGramIOS3PresentingViewControllerKey);
        if (presenter != nil)
            return presenter;
        UIViewController *nextParent = parent.parentViewController;
        if (nextParent == parent)
            break;
        parent = nextParent;
    }

    return nil;
}

- (void)lightgramIOS3Fallback_presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)animated completion:(void (^)(void))completion
{
    if (viewControllerToPresent != nil)
        objc_setAssociatedObject(viewControllerToPresent, &LightGramIOS3PresentingViewControllerKey, self, OBJC_ASSOCIATION_ASSIGN);
    [self presentModalViewController:viewControllerToPresent animated:animated];
    if (completion != nil)
        completion();
}

- (void)lightgramIOS3Fallback_dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion
{
    UIViewController *presenter = [self presentingViewController];
    if (presenter != nil)
    {
        objc_setAssociatedObject(self, &LightGramIOS3PresentingViewControllerKey, nil, OBJC_ASSOCIATION_ASSIGN);
        [presenter dismissModalViewControllerAnimated:animated];
    }
    else
    {
        UIViewController *presented = self.modalViewController;
        if (presented != nil)
            objc_setAssociatedObject(presented, &LightGramIOS3PresentingViewControllerKey, nil, OBJC_ASSOCIATION_ASSIGN);
        [self dismissModalViewControllerAnimated:animated];
    }
    if (completion != nil)
        completion();
}

@end
#endif


@implementation TGIOS3OrderedSet

- (instancetype)initWithArray:(NSArray *)array
{
    self = [super init];
    if (self != nil)
    {
        NSMutableArray *objects = [[NSMutableArray alloc] init];
        for (id object in array)
        {
            if (![objects containsObject:object])
                [objects addObject:object];
        }
        _lightgramObjects = [objects copy];
        [objects release];
    }
    return self;
}

- (void)dealloc
{
    [_lightgramObjects release];
    [super dealloc];
}

- (NSUInteger)count
{
    return [_lightgramObjects count];
}

- (NSArray *)array
{
    return _lightgramObjects;
}

- (id)objectAtIndex:(NSUInteger)index
{
    return [_lightgramObjects objectAtIndex:index];
}

- (BOOL)containsObject:(id)object
{
    return [_lightgramObjects containsObject:object];
}

- (NSArray *)allObjects
{
    return _lightgramObjects;
}

- (id)firstObject
{
    return [_lightgramObjects firstObject];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)buffer count:(NSUInteger)len
{
    return [_lightgramObjects countByEnumeratingWithState:state objects:buffer count:len];
}

@end

@implementation TGIOS3MutableOrderedSet

- (instancetype)init
{
    self = [super init];
    if (self != nil)
        _lightgramObjects = [[NSMutableArray alloc] init];
    return self;
}

- (instancetype)initWithArray:(NSArray *)array
{
    self = [super initWithArray:array];
    if (self != nil)
    {
        NSArray *objects = _lightgramObjects;
        _lightgramObjects = [objects mutableCopy];
        [objects release];
    }
    return self;
}

- (void)addObject:(id)object
{
    if (![_lightgramObjects containsObject:object])
        [(NSMutableArray *)_lightgramObjects addObject:object];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[TGIOS3OrderedSet allocWithZone:zone] initWithArray:_lightgramObjects];
}

@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@implementation TGIOS3MutableParagraphStyle

@synthesize lineSpacing = _lineSpacing;
@synthesize lineBreakMode = _lineBreakMode;
@synthesize alignment = _alignment;
@synthesize paragraphSpacing = _paragraphSpacing;
@synthesize firstLineHeadIndent = _firstLineHeadIndent;
@synthesize lineHeightMultiple = _lineHeightMultiple;

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _lineBreakMode = NSLineBreakByWordWrapping;
        _alignment = NSTextAlignmentLeft;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    TGIOS3MutableParagraphStyle *copy = [[[self class] allocWithZone:zone] init];
    copy.lineSpacing = _lineSpacing;
    copy.lineBreakMode = _lineBreakMode;
    copy.alignment = _alignment;
    copy.paragraphSpacing = _paragraphSpacing;
    copy.firstLineHeadIndent = _firstLineHeadIndent;
    copy.lineHeightMultiple = _lineHeightMultiple;
    return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [self copyWithZone:zone];
}

@end
#endif

@interface TGIOS3AttributedString ()
{
@protected
    NSUInteger _lightgramRunCount;
    NSUInteger _lightgramRunCapacity;
    NSUInteger *_lightgramRunStarts;
    NSDictionary **_lightgramRunAttributes;
}
- (void)lightgram_ensureRunCapacity:(NSUInteger)capacity;
- (void)lightgram_insertRunAtIndex:(NSUInteger)index start:(NSUInteger)start attributes:(NSDictionary *)attributes;
- (void)lightgram_removeRunsInRange:(NSRange)runRange;
- (NSUInteger)lightgram_runEnd:(NSUInteger)index;
- (NSUInteger)lightgram_runIndexForLocation:(NSUInteger)location;
- (NSUInteger)lightgram_splitAtLocation:(NSUInteger)location;
- (void)lightgram_normalizeRuns;
- (void)lightgram_replaceCharactersInRange:(NSRange)range withString:(NSString *)string attributes:(NSDictionary *)attributes;
@end

@implementation TGIOS3AttributedString

- (instancetype)init
{
    return [self initWithString:@""];
}

- (instancetype)initWithString:(NSString *)string
{
    return [self initWithString:string attributes:nil];
}

- (instancetype)initWithString:(NSString *)string attributes:(NSDictionary *)attributes
{
    self = [super init];
    if (self != nil)
    {
        _lightgramString = [(string == nil ? @"" : string) mutableCopy];
        if ([_lightgramString length] != 0)
            [self lightgram_insertRunAtIndex:0 start:0 attributes:attributes];
    }
    return self;
}

- (instancetype)initWithAttributedString:(TGIOS3AttributedString *)attributedString
{
    self = [self initWithString:[attributedString string] attributes:nil];
    if (self != nil)
    {
        [self lightgram_removeRunsInRange:NSMakeRange(0, _lightgramRunCount)];
        NSUInteger index = 0;
        NSUInteger length = [attributedString length];
        while (index < length)
        {
            NSRange range = NSMakeRange(index, 1);
            NSDictionary *attributes = [attributedString attributesAtIndex:index effectiveRange:&range];
            if (range.location != index || range.length == 0)
                range = NSMakeRange(index, 1);
            [self lightgram_insertRunAtIndex:_lightgramRunCount start:index attributes:attributes];
            index = NSMaxRange(range);
        }
        [self lightgram_normalizeRuns];
    }
    return self;
}

- (void)dealloc
{
    [self lightgram_removeRunsInRange:NSMakeRange(0, _lightgramRunCount)];
    free(_lightgramRunStarts);
    free(_lightgramRunAttributes);
    [_lightgramString release];
    [super dealloc];
}

- (void)lightgram_ensureRunCapacity:(NSUInteger)capacity
{
    if (capacity <= _lightgramRunCapacity)
        return;
    NSUInteger newCapacity = MAX(capacity, MAX((NSUInteger)4, _lightgramRunCapacity * 2));
    NSUInteger *starts = (NSUInteger *)realloc(_lightgramRunStarts, newCapacity * sizeof(NSUInteger));
    if (starts == NULL)
        return;
    _lightgramRunStarts = starts;
    NSDictionary **attributes = (NSDictionary **)realloc(_lightgramRunAttributes, newCapacity * sizeof(NSDictionary *));
    if (attributes == NULL)
        return;
    _lightgramRunAttributes = attributes;
    _lightgramRunCapacity = newCapacity;
}

- (void)lightgram_insertRunAtIndex:(NSUInteger)index start:(NSUInteger)start attributes:(NSDictionary *)attributes
{
    [self lightgram_ensureRunCapacity:_lightgramRunCount + 1];
    if (_lightgramRunCount + 1 > _lightgramRunCapacity)
        return;
    memmove(_lightgramRunStarts + index + 1, _lightgramRunStarts + index, (_lightgramRunCount - index) * sizeof(NSUInteger));
    memmove(_lightgramRunAttributes + index + 1, _lightgramRunAttributes + index, (_lightgramRunCount - index) * sizeof(NSDictionary *));
    _lightgramRunStarts[index] = start;
    _lightgramRunAttributes[index] = [(attributes == nil ? [NSDictionary dictionary] : attributes) copy];
    _lightgramRunCount++;
}

- (void)lightgram_removeRunsInRange:(NSRange)runRange
{
    if (runRange.length == 0)
        return;
    for (NSUInteger index = runRange.location; index < NSMaxRange(runRange); index++)
        [_lightgramRunAttributes[index] release];
    NSUInteger tail = _lightgramRunCount - NSMaxRange(runRange);
    memmove(_lightgramRunStarts + runRange.location, _lightgramRunStarts + NSMaxRange(runRange), tail * sizeof(NSUInteger));
    memmove(_lightgramRunAttributes + runRange.location, _lightgramRunAttributes + NSMaxRange(runRange), tail * sizeof(NSDictionary *));
    _lightgramRunCount -= runRange.length;
}

- (NSUInteger)lightgram_runEnd:(NSUInteger)index
{
    return index + 1 < _lightgramRunCount ? _lightgramRunStarts[index + 1] : [_lightgramString length];
}

- (NSUInteger)lightgram_runIndexForLocation:(NSUInteger)location
{
    NSUInteger low = 0;
    NSUInteger high = _lightgramRunCount;
    while (high - low > 1)
    {
        NSUInteger middle = low + (high - low) / 2;
        if (_lightgramRunStarts[middle] <= location)
            low = middle;
        else
            high = middle;
    }
    return low;
}

- (NSUInteger)lightgram_splitAtLocation:(NSUInteger)location
{
    if (location >= [_lightgramString length] || _lightgramRunCount == 0)
        return _lightgramRunCount;
    NSUInteger index = [self lightgram_runIndexForLocation:location];
    if (_lightgramRunStarts[index] == location)
        return index;
    [self lightgram_insertRunAtIndex:index + 1 start:location attributes:_lightgramRunAttributes[index]];
    return index + 1;
}

- (void)lightgram_normalizeRuns
{
    NSUInteger index = 0;
    while (index < _lightgramRunCount)
    {
        if ([self lightgram_runEnd:index] <= _lightgramRunStarts[index])
        {
            [self lightgram_removeRunsInRange:NSMakeRange(index, 1)];
            continue;
        }
        if (index > 0 && [_lightgramRunAttributes[index - 1] isEqual:_lightgramRunAttributes[index]])
        {
            [self lightgram_removeRunsInRange:NSMakeRange(index, 1)];
            continue;
        }
        index++;
    }
}

- (void)lightgram_replaceCharactersInRange:(NSRange)range withString:(NSString *)string attributes:(NSDictionary *)attributes
{
    NSDictionary *runAttributes = [(attributes == nil ? [NSDictionary dictionary] : attributes) copy];
    NSString *replacement = [(string == nil ? @"" : string) copy];
    NSUInteger length = [_lightgramString length];
    NSUInteger location = MIN(range.location, length);
    NSUInteger end = MIN(MAX(NSMaxRange(range), location), length);
    NSUInteger first = [self lightgram_splitAtLocation:location];
    NSUInteger last = [self lightgram_splitAtLocation:end];
    [self lightgram_removeRunsInRange:NSMakeRange(first, last - first)];
    [_lightgramString replaceCharactersInRange:NSMakeRange(location, end - location) withString:replacement];
    NSUInteger replacementLength = [replacement length];
    for (NSUInteger index = first; index < _lightgramRunCount; index++)
        _lightgramRunStarts[index] = _lightgramRunStarts[index] - (end - location) + replacementLength;
    if (replacementLength != 0)
        [self lightgram_insertRunAtIndex:first start:location attributes:runAttributes];
    [self lightgram_normalizeRuns];
    [replacement release];
    [runAttributes release];
}

- (NSString *)string
{
    return _lightgramString;
}

- (NSUInteger)length
{
    return [_lightgramString length];
}

- (CGSize)size
{
    CGFloat width = 0.0f;
    CGFloat height = 0.0f;
    NSUInteger index = 0;
    while (index < [self length])
    {
        NSRange range = NSMakeRange(index, 1);
        NSDictionary *attributes = [self attributesAtIndex:index effectiveRange:&range];
        UIFont *font = [attributes objectForKey:@"NSFont"];
        if (![font isKindOfClass:[UIFont class]])
            font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
        NSString *substring = [_lightgramString substringWithRange:range];
        CGSize runSize = [substring sizeWithFont:font];
        width += runSize.width;
        height = MAX(height, runSize.height);
        index = NSMaxRange(range);
    }
    return CGSizeMake(width, height);
}

- (void)drawAtPoint:(CGPoint)point
{
    CGFloat x = point.x;
    NSUInteger index = 0;
    while (index < [self length])
    {
        NSRange range = NSMakeRange(index, 1);
        NSDictionary *attributes = [self attributesAtIndex:index effectiveRange:&range];
        UIFont *font = [attributes objectForKey:@"NSFont"];
        if (![font isKindOfClass:[UIFont class]])
            font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
        UIColor *color = [attributes objectForKey:@"NSColor"];
        if ([color isKindOfClass:[UIColor class]])
            [color set];
        NSString *substring = [_lightgramString substringWithRange:range];
        [substring drawAtPoint:CGPointMake(x, point.y) withFont:font];
        x += [substring sizeWithFont:font].width;
        index = NSMaxRange(range);
    }
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{
    if (location >= [_lightgramString length] || _lightgramRunCount == 0)
    {
        if (range != NULL)
            *range = NSMakeRange(NSNotFound, 0);
        return [NSDictionary dictionary];
    }
    NSUInteger index = [self lightgram_runIndexForLocation:location];
    if (range != NULL)
        *range = NSMakeRange(_lightgramRunStarts[index], [self lightgram_runEnd:index] - _lightgramRunStarts[index]);
    return _lightgramRunAttributes[index];
}

- (id)attribute:(NSString *)attributeName atIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{
    return [[self attributesAtIndex:location effectiveRange:range] objectForKey:attributeName];
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)location longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit
{
    NSRange effectiveRange = NSMakeRange(NSNotFound, 0);
    NSDictionary *attributes = [self attributesAtIndex:location effectiveRange:&effectiveRange];
    if (range != NULL)
        *range = effectiveRange.location == NSNotFound ? effectiveRange : NSIntersectionRange(effectiveRange, rangeLimit);
    return attributes;
}

- (id)attribute:(NSString *)attributeName atIndex:(NSUInteger)location longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit
{
    if (location >= [_lightgramString length] || _lightgramRunCount == 0)
    {
        if (range != NULL)
            *range = NSMakeRange(NSNotFound, 0);
        return nil;
    }
    NSUInteger index = [self lightgram_runIndexForLocation:location];
    id value = [_lightgramRunAttributes[index] objectForKey:attributeName];
    if (range != NULL)
    {
        NSUInteger first = index;
        while (first > 0)
        {
            id candidate = [_lightgramRunAttributes[first - 1] objectForKey:attributeName];
            if (candidate != value && ![candidate isEqual:value])
                break;
            first--;
        }
        NSUInteger last = index;
        while (last + 1 < _lightgramRunCount)
        {
            id candidate = [_lightgramRunAttributes[last + 1] objectForKey:attributeName];
            if (candidate != value && ![candidate isEqual:value])
                break;
            last++;
        }
        NSUInteger lowerBound = MIN(rangeLimit.location, [_lightgramString length]);
        NSUInteger upperBound = MIN(NSMaxRange(rangeLimit), [_lightgramString length]);
        NSUInteger start = MAX(_lightgramRunStarts[first], lowerBound);
        NSUInteger end = MIN([self lightgram_runEnd:last], upperBound);
        *range = NSMakeRange(start, end > start ? end - start : 0);
    }
    return value;
}

- (TGIOS3AttributedString *)attributedSubstringFromRange:(NSRange)range
{
    NSRange validRange = NSIntersectionRange(range, NSMakeRange(0, [self length]));
    TGIOS3MutableAttributedString *result = [[[TGIOS3MutableAttributedString alloc] initWithString:[_lightgramString substringWithRange:validRange]] autorelease];
    NSUInteger index = validRange.location;
    while (index < NSMaxRange(validRange))
    {
        NSRange runRange = NSMakeRange(index, 1);
        NSDictionary *attributes = [self attributesAtIndex:index effectiveRange:&runRange];
        NSRange intersection = NSIntersectionRange(runRange, validRange);
        if (intersection.length == 0)
            break;
        [result setAttributes:attributes range:NSMakeRange(intersection.location - validRange.location, intersection.length)];
        index = NSMaxRange(intersection);
    }
    return result;
}

- (BOOL)isEqualToAttributedString:(TGIOS3AttributedString *)other
{
    if (other == nil || [self length] != [other length] || ![[self string] isEqualToString:[other string]])
        return NO;
    NSUInteger index = 0;
    while (index < [self length])
    {
        NSRange range = NSMakeRange(index, 1);
        NSRange otherRange = NSMakeRange(index, 1);
        NSDictionary *attributes = [self attributesAtIndex:index effectiveRange:&range];
        NSDictionary *otherAttributes = [other attributesAtIndex:index effectiveRange:&otherRange];
        if (![attributes isEqual:otherAttributes])
            return NO;
        index = MIN(NSMaxRange(range), NSMaxRange(otherRange));
    }
    return YES;
}

- (void)enumerateAttributesInRange:(NSRange)enumerationRange options:(NSUInteger)opts usingBlock:(void (^)(NSDictionary *, NSRange, BOOL *))block
{
    if (block == nil)
        return;
    NSRange validRange = NSIntersectionRange(enumerationRange, NSMakeRange(0, [self length]));
    BOOL stop = NO;
    if ((opts & (1 << 1)) != 0)
    {
        NSUInteger index = NSMaxRange(validRange);
        while (index > validRange.location && !stop)
        {
            index--;
            NSRange effectiveRange;
            NSDictionary *attributes = [self attributesAtIndex:index effectiveRange:&effectiveRange];
            effectiveRange = NSIntersectionRange(effectiveRange, validRange);
            block(attributes, effectiveRange, &stop);
            index = effectiveRange.location;
        }
    }
    else
    {
        NSUInteger index = validRange.location;
        while (index < NSMaxRange(validRange) && !stop)
        {
            NSRange effectiveRange;
            NSDictionary *attributes = [self attributesAtIndex:index effectiveRange:&effectiveRange];
            effectiveRange = NSIntersectionRange(effectiveRange, validRange);
            block(attributes, effectiveRange, &stop);
            index = NSMaxRange(effectiveRange);
        }
    }
}

- (void)enumerateAttribute:(NSString *)attrName inRange:(NSRange)enumerationRange options:(NSUInteger)opts usingBlock:(void (^)(id, NSRange, BOOL *))block
{
    if (block == nil)
        return;
    [self enumerateAttributesInRange:enumerationRange options:opts usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
        block([attributes objectForKey:attrName], range, stop);
    }];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[TGIOS3MutableAttributedString allocWithZone:zone] initWithAttributedString:self];
}

@end

@implementation TGIOS3MutableAttributedString

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string
{
    NSUInteger location = MIN(range.location, [self length]);
    NSDictionary *attributes = location < [self length] ? [self attributesAtIndex:location effectiveRange:NULL] : [NSDictionary dictionary];
    [self lightgram_replaceCharactersInRange:range withString:string attributes:attributes];
}

- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)range
{
    NSRange validRange = NSIntersectionRange(range, NSMakeRange(0, [self length]));
    if (validRange.length == 0)
        return;
    NSDictionary *runAttributes = [(attributes == nil ? [NSDictionary dictionary] : attributes) copy];
    NSUInteger first = [self lightgram_splitAtLocation:validRange.location];
    NSUInteger last = [self lightgram_splitAtLocation:NSMaxRange(validRange)];
    [self lightgram_removeRunsInRange:NSMakeRange(first, last - first)];
    [self lightgram_insertRunAtIndex:first start:validRange.location attributes:runAttributes];
    [self lightgram_normalizeRuns];
    [runAttributes release];
}

- (void)lightgram_updateAttributesInRange:(NSRange)range usingBlock:(void (^)(NSMutableDictionary *attributes))block
{
    NSRange validRange = NSIntersectionRange(range, NSMakeRange(0, [self length]));
    if (validRange.length == 0)
        return;
    NSUInteger first = [self lightgram_splitAtLocation:validRange.location];
    NSUInteger last = [self lightgram_splitAtLocation:NSMaxRange(validRange)];
    for (NSUInteger index = first; index < last; index++)
    {
        NSMutableDictionary *attributes = [_lightgramRunAttributes[index] mutableCopy];
        block(attributes);
        [_lightgramRunAttributes[index] release];
        _lightgramRunAttributes[index] = [attributes copy];
        [attributes release];
    }
    [self lightgram_normalizeRuns];
}

- (void)addAttribute:(NSString *)name value:(id)value range:(NSRange)range
{
    if (name == nil || value == nil)
        return;
    [self lightgram_updateAttributesInRange:range usingBlock:^(NSMutableDictionary *attributes)
    {
        [attributes setObject:value forKey:name];
    }];
}

- (void)addAttributes:(NSDictionary *)attributes range:(NSRange)range
{
    if ([attributes count] == 0)
        return;
    [self lightgram_updateAttributesInRange:range usingBlock:^(NSMutableDictionary *current)
    {
        [current addEntriesFromDictionary:attributes];
    }];
}

- (void)removeAttribute:(NSString *)name range:(NSRange)range
{
    if (name == nil)
        return;
    [self lightgram_updateAttributesInRange:range usingBlock:^(NSMutableDictionary *attributes)
    {
        [attributes removeObjectForKey:name];
    }];
}

- (void)appendAttributedString:(TGIOS3AttributedString *)attributedString
{
    [self insertAttributedString:attributedString atIndex:[self length]];
}

- (void)insertAttributedString:(TGIOS3AttributedString *)attributedString atIndex:(NSUInteger)index
{
    if (attributedString == nil || index > [self length])
        return;
    TGIOS3AttributedString *source = attributedString == self ? [[self copy] autorelease] : attributedString;
    [self lightgram_replaceCharactersInRange:NSMakeRange(index, 0) withString:[source string] attributes:nil];
    NSUInteger offset = 0;
    NSUInteger length = [source length];
    while (offset < length)
    {
        NSRange range = NSMakeRange(offset, 1);
        NSDictionary *attributes = [source attributesAtIndex:offset effectiveRange:&range];
        if (range.location != offset || range.length == 0)
            range = NSMakeRange(offset, 1);
        NSUInteger end = MIN(NSMaxRange(range), length);
        [self setAttributes:attributes range:NSMakeRange(index + offset, end - offset)];
        offset = end;
    }
}

- (void)deleteCharactersInRange:(NSRange)range
{
    [self replaceCharactersInRange:range withString:@""];
}

- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(TGIOS3AttributedString *)attributedString
{
    TGIOS3AttributedString *source = attributedString == self ? [[self copy] autorelease] : attributedString;
    NSUInteger location = MIN(range.location, [self length]);
    NSUInteger end = MIN(MAX(NSMaxRange(range), location), [self length]);
    [self deleteCharactersInRange:NSMakeRange(location, end - location)];
    [self insertAttributedString:source atIndex:location];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[TGIOS3AttributedString allocWithZone:zone] initWithAttributedString:self];
}

@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000

static BOOL LightGramIOS3IsLowSurrogate(unichar value)
{
    return value >= 0xdc00 && value <= 0xdfff;
}

static BOOL LightGramIOS3IsHighSurrogate(unichar value)
{
    return value >= 0xd800 && value <= 0xdbff;
}

static uint32_t LightGramIOS3CodePointAtIndex(NSString *string, NSUInteger index, NSUInteger *length)
{
    unichar high = [string characterAtIndex:index];
    if (LightGramIOS3IsHighSurrogate(high) && index + 1 < [string length])
    {
        unichar low = [string characterAtIndex:index + 1];
        if (LightGramIOS3IsLowSurrogate(low))
        {
            if (length != NULL)
                *length = 2;
            return (((uint32_t)high - 0xd800) << 10) + ((uint32_t)low - 0xdc00) + 0x10000;
        }
    }
    if (length != NULL)
        *length = 1;
    return high;
}

static BOOL LightGramIOS3IsCombiningCodePoint(uint32_t value)
{
    return (value >= 0x0300 && value <= 0x036f) ||
        (value >= 0x1ab0 && value <= 0x1aff) ||
        (value >= 0x1dc0 && value <= 0x1dff) ||
        (value >= 0x20d0 && value <= 0x20ff) ||
        (value >= 0xfe20 && value <= 0xfe2f) ||
        (value >= 0xfe00 && value <= 0xfe0f) ||
        (value >= 0x1f3fb && value <= 0x1f3ff) ||
        (value >= 0xe0100 && value <= 0xe01ef);
}

static NSRange LightGramIOS3ComposedRange(NSString *string, NSUInteger index, NSUInteger limit)
{
    NSUInteger scalarLength = 0;
    LightGramIOS3CodePointAtIndex(string, index, &scalarLength);
    NSUInteger end = MIN(index + scalarLength, limit);
    while (end < limit)
    {
        NSUInteger nextLength = 0;
        uint32_t next = LightGramIOS3CodePointAtIndex(string, end, &nextLength);
        if (LightGramIOS3IsCombiningCodePoint(next))
        {
            end = MIN(end + nextLength, limit);
            continue;
        }
        if (next == 0x200d)
        {
            end = MIN(end + nextLength, limit);
            if (end < limit)
            {
                NSUInteger joinedLength = 0;
                LightGramIOS3CodePointAtIndex(string, end, &joinedLength);
                end = MIN(end + joinedLength, limit);
            }
            continue;
        }
        break;
    }
    return NSMakeRange(index, end - index);
}

@implementation NSString (LightGramIOS3EnumerationCompatibilityFallback)

- (void)lightgramIOS3Fallback_enumerateSubstringsInRange:(NSRange)range options:(NSStringEnumerationOptions)opts usingBlock:(void (^)(NSString *, NSRange, NSRange, BOOL *))block
{
    if (block == nil)
        return;

    NSRange validRange = NSIntersectionRange(range, NSMakeRange(0, [self length]));
    if ((opts & 0xff) != NSStringEnumerationByComposedCharacterSequences)
    {
        BOOL stop = NO;
        NSString *substring = [self substringWithRange:validRange];
        block((opts & NSStringEnumerationSubstringNotRequired) != 0 ? nil : substring, validRange, validRange, &stop);
        return;
    }

    NSMutableArray *ranges = [NSMutableArray array];
    NSUInteger index = validRange.location;
    NSUInteger limit = NSMaxRange(validRange);
    while (index < limit)
    {
        NSRange composedRange = LightGramIOS3ComposedRange(self, index, limit);
        [ranges addObject:[NSValue valueWithRange:composedRange]];
        index = NSMaxRange(composedRange);
    }

    BOOL stop = NO;
    if ((opts & NSStringEnumerationReverse) != 0)
    {
        NSUInteger count = [ranges count];
        while (count > 0 && !stop)
        {
            NSRange composedRange = [[ranges objectAtIndex:--count] rangeValue];
            NSString *substring = (opts & NSStringEnumerationSubstringNotRequired) != 0 ? nil : [self substringWithRange:composedRange];
            block(substring, composedRange, composedRange, &stop);
        }
    }
    else
    {
        for (NSValue *value in ranges)
        {
            NSRange composedRange = [value rangeValue];
            NSString *substring = (opts & NSStringEnumerationSubstringNotRequired) != 0 ? nil : [self substringWithRange:composedRange];
            block(substring, composedRange, composedRange, &stop);
            if (stop)
                break;
        }
    }
}

- (void)lightgramIOS3Fallback_enumerateLinesUsingBlock:(void (^)(NSString *, BOOL *))block
{
    if (block == nil)
        return;

    NSUInteger length = [self length];
    NSUInteger start = 0;
    BOOL stop = NO;

    while (start < length && !stop)
    {
        NSUInteger end = start;
        while (end < length)
        {
            unichar character = [self characterAtIndex:end];
            if (character == '\r' || character == '\n')
                break;
            end++;
        }

        block([self substringWithRange:NSMakeRange(start, end - start)], &stop);
        if (stop || end >= length)
            break;

        unichar separator = [self characterAtIndex:end++];
        if (separator == '\r' && end < length && [self characterAtIndex:end] == '\n')
            end++;
        start = end;
    }
}

@end

static char LightGramIOS3LabelAttributedTextKey;

@implementation UILabel (LightGramIOS3AttributedTextCompatibilityFallback)

- (TGIOS3AttributedString *)lightgramIOS3Fallback_attributedText
{
    return objc_getAssociatedObject(self, &LightGramIOS3LabelAttributedTextKey);
}

- (void)lightgramIOS3Fallback_setAttributedText:(TGIOS3AttributedString *)attributedText
{
    objc_setAssociatedObject(self, &LightGramIOS3LabelAttributedTextKey, attributedText, OBJC_ASSOCIATION_COPY);
    self.text = [attributedText string];
    if ([attributedText length] != 0)
    {
        NSDictionary *attributes = [attributedText attributesAtIndex:0 effectiveRange:NULL];
        UIFont *font = [attributes objectForKey:@"NSFont"];
        UIColor *color = [attributes objectForKey:@"NSColor"];
        id paragraphStyle = [attributes objectForKey:@"NSParagraphStyle"];
        if (font != nil)
            self.font = font;
        if (color != nil)
            self.textColor = color;
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
        if ([paragraphStyle isKindOfClass:[TGIOS3MutableParagraphStyle class]])
        {
            self.lineBreakMode = (UILineBreakMode)[paragraphStyle lineBreakMode];
            self.textAlignment = (UITextAlignment)[paragraphStyle alignment];
        }
#endif
    }
}

@end

static int LightGramIOS3JSONHexDigit(unichar c)
{
    if (c >= '0' && c <= '9')
        return (int)(c - '0');
    if (c >= 'a' && c <= 'f')
        return (int)(c - 'a') + 10;
    if (c >= 'A' && c <= 'F')
        return (int)(c - 'A') + 10;
    return -1;
}

@interface LightGramIOS3JSONParser : NSObject
{
    NSString *_lightgramString;
    NSUInteger _lightgramIndex;
    NSUInteger _lightgramLength;
    NSJSONReadingOptions _lightgramOptions;
    NSError **_lightgramError;
}
- (instancetype)initWithString:(NSString *)string options:(NSJSONReadingOptions)options error:(NSError **)error;
- (void)skipWhitespace;
- (BOOL)consumeLiteral:(NSString *)literal;
- (NSString *)parseString;
- (NSNumber *)parseNumber;
- (id)parseArray;
- (id)parseObject;
- (id)parseValue;
- (id)parse;
@end

@implementation LightGramIOS3JSONParser

- (instancetype)initWithString:(NSString *)string options:(NSJSONReadingOptions)options error:(NSError **)error
{
    self = [super init];
    if (self != nil)
    {
        _lightgramString = [string copy];
        _lightgramLength = [_lightgramString length];
        _lightgramOptions = options;
        _lightgramError = error;
        if (_lightgramError != NULL)
            *_lightgramError = nil;
    }
    return self;
}

- (void)dealloc
{
    [_lightgramString release];
    [super dealloc];
}

- (void)setError:(NSString *)description
{
    if (_lightgramError != NULL && *_lightgramError == nil)
    {
        NSDictionary *userInfo = description == nil ? nil : [NSDictionary dictionaryWithObject:description forKey:NSLocalizedDescriptionKey];
        *_lightgramError = [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:userInfo];
    }
}

- (void)skipWhitespace
{
    while (_lightgramIndex < _lightgramLength)
    {
        unichar c = [_lightgramString characterAtIndex:_lightgramIndex];
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == 0xfeff)
            _lightgramIndex++;
        else
            break;
    }
}

- (BOOL)consumeLiteral:(NSString *)literal
{
    NSUInteger length = [literal length];
    if (_lightgramIndex + length > _lightgramLength)
        return NO;
    if (![[_lightgramString substringWithRange:NSMakeRange(_lightgramIndex, length)] isEqualToString:literal])
        return NO;
    _lightgramIndex += length;
    return YES;
}

- (NSString *)parseString
{
    if (_lightgramIndex >= _lightgramLength || [_lightgramString characterAtIndex:_lightgramIndex] != '"')
        return nil;
    _lightgramIndex++;
    NSMutableString *result = [NSMutableString string];
    while (_lightgramIndex < _lightgramLength)
    {
        unichar c = [_lightgramString characterAtIndex:_lightgramIndex++];
        if (c == '"')
        {
            if ((_lightgramOptions & NSJSONReadingMutableLeaves) != 0)
                return [NSMutableString stringWithString:result];
            return [NSString stringWithString:result];
        }
        if (c < 0x20)
        {
            [self setError:@"Invalid control character in JSON string"];
            return nil;
        }
        if (c != '\\')
        {
            [result appendFormat:@"%C", c];
            continue;
        }
        if (_lightgramIndex >= _lightgramLength)
        {
            [self setError:@"Invalid escape sequence in JSON string"];
            return nil;
        }
        unichar escape = [_lightgramString characterAtIndex:_lightgramIndex++];
        switch (escape)
        {
            case '"': [result appendString:@"\""]; break;
            case '\\': [result appendString:@"\\"]; break;
            case '/': [result appendString:@"/"]; break;
            case 'b': [result appendFormat:@"%C", (unichar)'\b']; break;
            case 'f': [result appendFormat:@"%C", (unichar)'\f']; break;
            case 'n': [result appendFormat:@"%C", (unichar)'\n']; break;
            case 'r': [result appendFormat:@"%C", (unichar)'\r']; break;
            case 't': [result appendFormat:@"%C", (unichar)'\t']; break;
            case 'u':
            {
                if (_lightgramIndex + 4 > _lightgramLength)
                {
                    [self setError:@"Invalid Unicode escape in JSON string"];
                    return nil;
                }
                unsigned int value = 0;
                for (NSUInteger i = 0; i < 4; i++)
                {
                    int digit = LightGramIOS3JSONHexDigit([_lightgramString characterAtIndex:_lightgramIndex + i]);
                    if (digit < 0)
                    {
                        [self setError:@"Invalid Unicode escape in JSON string"];
                        return nil;
                    }
                    value = (value << 4) | (unsigned int)digit;
                }
                _lightgramIndex += 4;
                unichar high = (unichar)value;
                if (high >= 0xd800 && high <= 0xdbff)
                {
                    if (_lightgramIndex + 6 > _lightgramLength || [_lightgramString characterAtIndex:_lightgramIndex] != '\\' || [_lightgramString characterAtIndex:_lightgramIndex + 1] != 'u')
                    {
                        [self setError:@"Invalid Unicode surrogate pair in JSON string"];
                        return nil;
                    }
                    _lightgramIndex += 2;
                    unsigned int lowValue = 0;
                    for (NSUInteger i = 0; i < 4; i++)
                    {
                        int digit = LightGramIOS3JSONHexDigit([_lightgramString characterAtIndex:_lightgramIndex + i]);
                        if (digit < 0)
                        {
                            [self setError:@"Invalid Unicode surrogate pair in JSON string"];
                            return nil;
                        }
                        lowValue = (lowValue << 4) | (unsigned int)digit;
                    }
                    _lightgramIndex += 4;
                    unichar low = (unichar)lowValue;
                    if (low < 0xdc00 || low > 0xdfff)
                    {
                        [self setError:@"Invalid Unicode surrogate pair in JSON string"];
                        return nil;
                    }
                    [result appendFormat:@"%C%C", high, low];
                }
                else if (high >= 0xdc00 && high <= 0xdfff)
                {
                    [self setError:@"Invalid Unicode surrogate pair in JSON string"];
                    return nil;
                }
                else
                    [result appendFormat:@"%C", high];
                break;
            }
            default:
                [self setError:@"Invalid escape sequence in JSON string"];
                return nil;
        }
    }
    [self setError:@"Unterminated JSON string"];
    return nil;
}

- (NSNumber *)parseNumber
{
    NSUInteger start = _lightgramIndex;
    if (_lightgramIndex < _lightgramLength && [_lightgramString characterAtIndex:_lightgramIndex] == '-')
        _lightgramIndex++;
    if (_lightgramIndex >= _lightgramLength)
    {
        [self setError:@"Invalid JSON number"];
        return nil;
    }
    unichar c = [_lightgramString characterAtIndex:_lightgramIndex];
    if (c == '0')
    {
        _lightgramIndex++;
        if (_lightgramIndex < _lightgramLength)
        {
            unichar next = [_lightgramString characterAtIndex:_lightgramIndex];
            if (next >= '0' && next <= '9')
            {
                [self setError:@"Invalid JSON number"];
                return nil;
            }
        }
    }
    else if (c >= '1' && c <= '9')
    {
        while (_lightgramIndex < _lightgramLength)
        {
            unichar digit = [_lightgramString characterAtIndex:_lightgramIndex];
            if (digit < '0' || digit > '9')
                break;
            _lightgramIndex++;
        }
    }
    else
    {
        [self setError:@"Invalid JSON number"];
        return nil;
    }
    BOOL floating = NO;
    if (_lightgramIndex < _lightgramLength && [_lightgramString characterAtIndex:_lightgramIndex] == '.')
    {
        floating = YES;
        _lightgramIndex++;
        NSUInteger digitsStart = _lightgramIndex;
        while (_lightgramIndex < _lightgramLength)
        {
            unichar digit = [_lightgramString characterAtIndex:_lightgramIndex];
            if (digit < '0' || digit > '9')
                break;
            _lightgramIndex++;
        }
        if (_lightgramIndex == digitsStart)
        {
            [self setError:@"Invalid JSON number"];
            return nil;
        }
    }
    if (_lightgramIndex < _lightgramLength)
    {
        unichar exponent = [_lightgramString characterAtIndex:_lightgramIndex];
        if (exponent == 'e' || exponent == 'E')
        {
            floating = YES;
            _lightgramIndex++;
            if (_lightgramIndex < _lightgramLength)
            {
                unichar sign = [_lightgramString characterAtIndex:_lightgramIndex];
                if (sign == '+' || sign == '-')
                    _lightgramIndex++;
            }
            NSUInteger digitsStart = _lightgramIndex;
            while (_lightgramIndex < _lightgramLength)
            {
                unichar digit = [_lightgramString characterAtIndex:_lightgramIndex];
                if (digit < '0' || digit > '9')
                    break;
                _lightgramIndex++;
            }
            if (_lightgramIndex == digitsStart)
            {
                [self setError:@"Invalid JSON number"];
                return nil;
            }
        }
    }
    NSString *numberString = [_lightgramString substringWithRange:NSMakeRange(start, _lightgramIndex - start)];
    const char *utf8 = [numberString UTF8String];
    if (utf8 == NULL)
    {
        [self setError:@"Invalid JSON number"];
        return nil;
    }
    if (!floating)
    {
        char *end = NULL;
        long long value = strtoll(utf8, &end, 10);
        if (end == NULL || *end != '\0')
        {
            [self setError:@"Invalid JSON number"];
            return nil;
        }
        return [NSNumber numberWithLongLong:value];
    }
    char *end = NULL;
    double value = strtod(utf8, &end);
    if (end == NULL || *end != '\0' || !isfinite(value))
    {
        [self setError:@"Invalid JSON number"];
        return nil;
    }
    return [NSNumber numberWithDouble:value];
}

- (id)parseArray
{
    _lightgramIndex++;
    NSMutableArray *result = [NSMutableArray array];
    [self skipWhitespace];
    if (_lightgramIndex < _lightgramLength && [_lightgramString characterAtIndex:_lightgramIndex] == ']')
    {
        _lightgramIndex++;
        return (_lightgramOptions & NSJSONReadingMutableContainers) != 0 ? result : [NSArray arrayWithArray:result];
    }
    while (_lightgramIndex < _lightgramLength)
    {
        id value = [self parseValue];
        if (value == nil)
            return nil;
        [result addObject:value];
        [self skipWhitespace];
        if (_lightgramIndex >= _lightgramLength)
            break;
        unichar c = [_lightgramString characterAtIndex:_lightgramIndex++];
        if (c == ']')
            return (_lightgramOptions & NSJSONReadingMutableContainers) != 0 ? result : [NSArray arrayWithArray:result];
        if (c != ',')
        {
            [self setError:@"Expected comma in JSON array"];
            return nil;
        }
        [self skipWhitespace];
    }
    [self setError:@"Unterminated JSON array"];
    return nil;
}

- (id)parseObject
{
    _lightgramIndex++;
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [self skipWhitespace];
    if (_lightgramIndex < _lightgramLength && [_lightgramString characterAtIndex:_lightgramIndex] == '}')
    {
        _lightgramIndex++;
        return (_lightgramOptions & NSJSONReadingMutableContainers) != 0 ? result : [NSDictionary dictionaryWithDictionary:result];
    }
    while (_lightgramIndex < _lightgramLength)
    {
        if ([_lightgramString characterAtIndex:_lightgramIndex] != '"')
        {
            [self setError:@"Expected string key in JSON object"];
            return nil;
        }
        NSString *key = [self parseString];
        if (key == nil)
            return nil;
        [self skipWhitespace];
        if (_lightgramIndex >= _lightgramLength || [_lightgramString characterAtIndex:_lightgramIndex] != ':')
        {
            [self setError:@"Expected colon in JSON object"];
            return nil;
        }
        _lightgramIndex++;
        [self skipWhitespace];
        id value = [self parseValue];
        if (value == nil)
            return nil;
        [result setObject:value forKey:key];
        [self skipWhitespace];
        if (_lightgramIndex >= _lightgramLength)
            break;
        unichar c = [_lightgramString characterAtIndex:_lightgramIndex++];
        if (c == '}')
            return (_lightgramOptions & NSJSONReadingMutableContainers) != 0 ? result : [NSDictionary dictionaryWithDictionary:result];
        if (c != ',')
        {
            [self setError:@"Expected comma in JSON object"];
            return nil;
        }
        [self skipWhitespace];
    }
    [self setError:@"Unterminated JSON object"];
    return nil;
}

- (id)parseValue
{
    [self skipWhitespace];
    if (_lightgramIndex >= _lightgramLength)
    {
        [self setError:@"Unexpected end of JSON input"];
        return nil;
    }
    unichar c = [_lightgramString characterAtIndex:_lightgramIndex];
    if (c == '"')
        return [self parseString];
    if (c == '{')
        return [self parseObject];
    if (c == '[')
        return [self parseArray];
    if (c == 't')
    {
        if ([self consumeLiteral:@"true"])
            return [NSNumber numberWithBool:YES];
    }
    else if (c == 'f')
    {
        if ([self consumeLiteral:@"false"])
            return [NSNumber numberWithBool:NO];
    }
    else if (c == 'n')
    {
        if ([self consumeLiteral:@"null"])
            return [NSNull null];
    }
    else if (c == '-' || (c >= '0' && c <= '9'))
        return [self parseNumber];
    [self setError:@"Invalid JSON value"];
    return nil;
}

- (id)parse
{
    [self skipWhitespace];
    id result = [self parseValue];
    if (result == nil)
        return nil;
    [self skipWhitespace];
    if (_lightgramIndex != _lightgramLength)
    {
        [self setError:@"Trailing data after JSON value"];
        return nil;
    }
    if ((_lightgramOptions & NSJSONReadingAllowFragments) == 0 && ![result isKindOfClass:[NSArray class]] && ![result isKindOfClass:[NSDictionary class]])
    {
        [self setError:@"Top-level JSON value must be an array or object"];
        return nil;
    }
    return result;
}

@end

static void LightGramIOS3JSONAppendIndent(NSMutableString *output, NSUInteger depth)
{
    for (NSUInteger i = 0; i < depth; i++)
        [output appendString:@"  "];
}

static void LightGramIOS3JSONAppendString(NSMutableString *output, NSString *string)
{
    [output appendString:@"\""];
    NSUInteger length = [string length];
    for (NSUInteger i = 0; i < length; i++)
    {
        unichar c = [string characterAtIndex:i];
        switch (c)
        {
            case '"': [output appendString:@"\\\""]; break;
            case '\\': [output appendString:@"\\\\"]; break;
            case '\b': [output appendString:@"\\b"]; break;
            case '\f': [output appendString:@"\\f"]; break;
            case '\n': [output appendString:@"\\n"]; break;
            case '\r': [output appendString:@"\\r"]; break;
            case '\t': [output appendString:@"\\t"]; break;
            default:
                if (c < 0x20 || c == 0x2028 || c == 0x2029)
                    [output appendFormat:@"\\u%04x", c];
                else
                    [output appendFormat:@"%C", c];
                break;
        }
    }
    [output appendString:@"\""];
}

static BOOL LightGramIOS3JSONAppendObject(NSMutableString *output, id object, NSJSONWritingOptions options, NSUInteger depth, NSError **error)
{
    BOOL pretty = (options & NSJSONWritingPrettyPrinted) != 0;
    if (object == nil || object == [NSNull null])
    {
        [output appendString:@"null"];
        return YES;
    }

    if ([object isKindOfClass:[NSString class]])
    {
        LightGramIOS3JSONAppendString(output, object);
        return YES;
    }

    if ([object isKindOfClass:[NSNumber class]])
    {
        if (object == (id)kCFBooleanTrue)
            [output appendString:@"true"];
        else if (object == (id)kCFBooleanFalse)
            [output appendString:@"false"];
        else
        {
            const char *type = [object objCType];
            if (type != NULL && (type[0] == 'f' || type[0] == 'd'))
            {
                double value = [object doubleValue];
                if (!isfinite(value))
                {
                    if (error != NULL)
                        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:nil];
                    return NO;
                }
            }
            [output appendString:[object stringValue]];
        }
        return YES;
    }

    if ([object isKindOfClass:[NSArray class]])
    {
        [output appendString:@"["];
        NSUInteger count = [object count];
        for (NSUInteger i = 0; i < count; i++)
        {
            if (i != 0)
                [output appendString:@","];
            if (pretty)
            {
                [output appendString:@"\n"];
                LightGramIOS3JSONAppendIndent(output, depth + 1);
            }
            if (!LightGramIOS3JSONAppendObject(output, [object objectAtIndex:i], options, depth + 1, error))
                return NO;
        }
        if (pretty && count != 0)
        {
            [output appendString:@"\n"];
            LightGramIOS3JSONAppendIndent(output, depth);
        }
        [output appendString:@"]"];
        return YES;
    }

    if ([object isKindOfClass:[NSDictionary class]])
    {
        [output appendString:@"{"];
        NSArray *keys = [object allKeys];
        NSUInteger count = [keys count];
        for (NSUInteger i = 0; i < count; i++)
        {
            id key = [keys objectAtIndex:i];
            if (![key isKindOfClass:[NSString class]])
            {
                if (error != NULL)
                    *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:nil];
                return NO;
            }
            if (i != 0)
                [output appendString:@","];
            if (pretty)
            {
                [output appendString:@"\n"];
                LightGramIOS3JSONAppendIndent(output, depth + 1);
            }
            LightGramIOS3JSONAppendString(output, key);
            [output appendString:pretty ? @": " : @":"];
            if (!LightGramIOS3JSONAppendObject(output, [object objectForKey:key], options, depth + 1, error))
                return NO;
        }
        if (pretty && count != 0)
        {
            [output appendString:@"\n"];
            LightGramIOS3JSONAppendIndent(output, depth);
        }
        [output appendString:@"}"];
        return YES;
    }

    if (error != NULL)
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:nil];
    return NO;
}

@implementation NSJSONSerialization

+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error
{
    if (error != NULL)
        *error = nil;
    if (data == nil)
    {
        if (error != NULL)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:nil];
        return nil;
    }

    NSString *string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    if (string == nil)
        string = [[[NSString alloc] initWithData:data encoding:NSUnicodeStringEncoding] autorelease];
    if (string == nil)
    {
        if (error != NULL)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:nil];
        return nil;
    }

    LightGramIOS3JSONParser *parser = [[[LightGramIOS3JSONParser alloc] initWithString:string options:opt error:error] autorelease];
    return [parser parse];
}

+ (NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error
{
    NSMutableString *output = [NSMutableString string];
    if (!LightGramIOS3JSONAppendObject(output, obj, opt, 0, error))
        return nil;
    return [output dataUsingEncoding:NSUTF8StringEncoding];
}

+ (BOOL)isValidJSONObject:(id)obj
{
    if (![obj isKindOfClass:[NSArray class]] && ![obj isKindOfClass:[NSDictionary class]])
        return NO;
    NSError *error = nil;
    return [self dataWithJSONObject:obj options:0 error:&error] != nil;
}

@end

@implementation NSFileManager (LightGramIOS3URLCompatibilityFallback)

- (BOOL)lightgramIOS3Fallback_removeItemAtURL:(NSURL *)URL error:(NSError **)error
{
    NSString *path = [URL path];
    if (path == nil)
        return NO;
    return [self removeItemAtPath:path error:error];
}

- (BOOL)lightgramIOS3Fallback_createDirectoryAtURL:(NSURL *)url withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error
{
    NSString *path = [url path];
    if (path == nil)
        return NO;
    return [self createDirectoryAtPath:path withIntermediateDirectories:createIntermediates attributes:attributes error:error];
}

- (NSURL *)lightgramIOS3Fallback_containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier
{
    return nil;
}

@end

@implementation NSURL (LightGramIOS3PathCompatibilityFallback)

- (NSURL *)lightgramIOS3Fallback_URLByAppendingPathComponent:(NSString *)pathComponent
{
    if (pathComponent == nil)
        return self;

    if ([[self scheme] isEqualToString:@"file"])
    {
        NSString *path = [[self path] stringByAppendingPathComponent:pathComponent];
        return path == nil ? nil : [NSURL fileURLWithPath:path];
    }

    NSString *base = [self absoluteString];
    if (base == nil)
        return nil;
    if (![base hasSuffix:@"/"])
        base = [base stringByAppendingString:@"/"];
    NSString *escaped = [pathComponent stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return [NSURL URLWithString:[base stringByAppendingString:escaped != nil ? escaped : pathComponent]];
}

- (NSURL *)lightgramIOS3Fallback_URLByAppendingPathComponent:(NSString *)pathComponent isDirectory:(BOOL)isDirectory
{
    if (pathComponent == nil || [pathComponent length] == 0)
        return self;

    NSString *component = pathComponent;
    if (isDirectory && ![component hasSuffix:@"/"])
        component = [component stringByAppendingString:@"/"];

    if ([[self scheme] isEqualToString:@"file"])
    {
        NSString *path = [[self path] stringByAppendingPathComponent:component];
        return path == nil ? nil : [NSURL fileURLWithPath:path];
    }

    return [self URLByAppendingPathComponent:component];
}

- (NSString *)lightgramIOS3Fallback_pathExtension
{
    return [[self path] pathExtension];
}

- (NSString *)lightgramIOS3Fallback_lastPathComponent
{
    return [[self path] lastPathComponent];
}

- (NSArray *)lightgramIOS3Fallback_pathComponents
{
    return [[self path] pathComponents];
}

@end

@implementation NSData (LightGramIOS3ReadingWritingCompatibilityFallback)

- (instancetype)lightgramIOS3Fallback_initWithContentsOfURL:(NSURL *)url options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr
{
    (void)readOptionsMask;
    id result = [self initWithContentsOfURL:url];
    if (result == nil && errorPtr != NULL)
        *errorPtr = [NSError errorWithDomain:@"NSCocoaErrorDomain" code:256 userInfo:nil];
    return result;
}

- (instancetype)lightgramIOS3Fallback_initWithContentsOfFile:(NSString *)path options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr
{
    (void)readOptionsMask;
    id result = [self initWithContentsOfFile:path];
    if (result == nil && errorPtr != NULL)
        *errorPtr = [NSError errorWithDomain:@"NSCocoaErrorDomain" code:256 userInfo:nil];
    return result;
}

+ (NSData *)lightgramIOS3Fallback_dataWithContentsOfURL:(NSURL *)url options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr
{
    return [[[self alloc] initWithContentsOfURL:url options:readOptionsMask error:errorPtr] autorelease];
}

+ (NSData *)lightgramIOS3Fallback_dataWithContentsOfFile:(NSString *)path options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr
{
    return [[[self alloc] initWithContentsOfFile:path options:readOptionsMask error:errorPtr] autorelease];
}

- (BOOL)lightgramIOS3Fallback_writeToURL:(NSURL *)url options:(NSDataWritingOptions)writeOptionsMask error:(NSError **)errorPtr
{
    BOOL result = [self writeToURL:url atomically:(writeOptionsMask & NSDataWritingAtomic) != 0];
    if (!result && errorPtr != NULL)
        *errorPtr = [NSError errorWithDomain:@"NSCocoaErrorDomain" code:512 userInfo:nil];
    return result;
}

@end

static char LightGramIOS3ButtonAttributedTitlesKey;

@implementation UIButton (LightGramIOS3AttributedTitleCompatibilityFallback)

- (void)lightgramIOS3Fallback_setAttributedTitle:(id)title forState:(UIControlState)state
{
    NSMutableDictionary *titles = objc_getAssociatedObject(self, &LightGramIOS3ButtonAttributedTitlesKey);
    if (titles == nil)
    {
        titles = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &LightGramIOS3ButtonAttributedTitlesKey, titles, OBJC_ASSOCIATION_RETAIN);
    }

    NSNumber *key = [NSNumber numberWithUnsignedInteger:state];
    if (title != nil)
        [titles setObject:title forKey:key];
    else
        [titles removeObjectForKey:key];

    NSString *string = [title respondsToSelector:@selector(string)] ? [title string] : nil;
    [self setTitle:string forState:state];

    if ([title respondsToSelector:@selector(length)] && [title length] != 0 && [title respondsToSelector:@selector(attributesAtIndex:effectiveRange:)])
    {
        NSDictionary *attributes = [title attributesAtIndex:0 effectiveRange:NULL];
        UIColor *color = [attributes objectForKey:@"NSColor"];
        UIFont *font = [attributes objectForKey:@"NSFont"];
        if (color != nil)
            [self setTitleColor:color forState:state];
        if (font != nil)
            self.titleLabel.font = font;
    }
}

- (id)lightgramIOS3Fallback_attributedTitleForState:(UIControlState)state
{
    NSDictionary *titles = objc_getAssociatedObject(self, &LightGramIOS3ButtonAttributedTitlesKey);
    return [titles objectForKey:[NSNumber numberWithUnsignedInteger:state]];
}

@end

#endif

typedef BOOL (*LightGramIOS3VideoCompatibilityFunction)(NSString *videoPath);
typedef void (*LightGramIOS3SaveVideoFunction)(NSString *videoPath, id completionTarget, SEL completionSelector, void *contextInfo);

static NSString *const LightGramIOS3CompatibilityErrorDomain = @"LightGramIOS3CompatibilityErrorDomain";

enum
{
    LightGramIOS3CompatibilityErrorUnsupported = 1
};

static pthread_once_t LightGramIOS3VideoAlbumFunctionsOnce = PTHREAD_ONCE_INIT;
static LightGramIOS3VideoCompatibilityFunction LightGramIOS3NativeVideoAtPathIsCompatible = NULL;
static LightGramIOS3SaveVideoFunction LightGramIOS3NativeSaveVideoAtPath = NULL;

static void LightGramIOS3InitializeVideoAlbumFunctions(void)
{
    LightGramIOS3NativeVideoAtPathIsCompatible = (LightGramIOS3VideoCompatibilityFunction)dlsym(RTLD_NEXT, "UIVideoAtPathIsCompatibleWithSavedPhotosAlbum");
    LightGramIOS3NativeSaveVideoAtPath = (LightGramIOS3SaveVideoFunction)dlsym(RTLD_NEXT, "UISaveVideoAtPathToSavedPhotosAlbum");
}

BOOL UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(NSString *videoPath)
{
    pthread_once(&LightGramIOS3VideoAlbumFunctionsOnce, LightGramIOS3InitializeVideoAlbumFunctions);
    return LightGramIOS3NativeVideoAtPathIsCompatible != NULL && LightGramIOS3NativeVideoAtPathIsCompatible(videoPath);
}

void UISaveVideoAtPathToSavedPhotosAlbum(NSString *videoPath, id completionTarget, SEL completionSelector, void *contextInfo)
{
    pthread_once(&LightGramIOS3VideoAlbumFunctionsOnce, LightGramIOS3InitializeVideoAlbumFunctions);
    if (LightGramIOS3NativeSaveVideoAtPath != NULL)
    {
        LightGramIOS3NativeSaveVideoAtPath(videoPath, completionTarget, completionSelector, contextInfo);
        return;
    }
    NSMethodSignature *signature = completionTarget == nil || completionSelector == NULL ? nil : [completionTarget methodSignatureForSelector:completionSelector];
    if (signature == nil)
        return;
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Saving videos to the Camera Roll requires iPhone OS 3.1" forKey:NSLocalizedDescriptionKey];
    NSError *error = [NSError errorWithDomain:LightGramIOS3CompatibilityErrorDomain code:LightGramIOS3CompatibilityErrorUnsupported userInfo:userInfo];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = completionTarget;
    invocation.selector = completionSelector;
    [invocation setArgument:&videoPath atIndex:2];
    [invocation setArgument:&error atIndex:3];
    [invocation setArgument:&contextInfo atIndex:4];
    [invocation retainArguments];
    [invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:NO];
}

static char LightGramIOS3ImagePickerCameraOverlayViewKey;

@implementation UIImagePickerController (LightGramIOS3CameraCompatibilityFallback)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

- (BOOL)lightgramIOS3Fallback_allowsEditing
{
    return self.allowsImageEditing;
}

- (void)lightgramIOS3Fallback_setAllowsEditing:(BOOL)allowsEditing
{
    self.allowsImageEditing = allowsEditing;
}

#pragma clang diagnostic pop

- (UIView *)lightgramIOS3Fallback_cameraOverlayView
{
    return objc_getAssociatedObject(self, &LightGramIOS3ImagePickerCameraOverlayViewKey);
}

- (void)lightgramIOS3Fallback_setCameraOverlayView:(UIView *)cameraOverlayView
{
    UIView *currentOverlayView = objc_getAssociatedObject(self, &LightGramIOS3ImagePickerCameraOverlayViewKey);
    if (currentOverlayView == cameraOverlayView)
        return;
    [currentOverlayView removeFromSuperview];
    objc_setAssociatedObject(self, &LightGramIOS3ImagePickerCameraOverlayViewKey, cameraOverlayView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (cameraOverlayView != nil)
        [self.view addSubview:cameraOverlayView];
}

@end

@interface LightGramIOS3FallbackMethodInstaller : NSObject
@end

@implementation LightGramIOS3FallbackMethodInstaller

+ (void)load
{
    Class classes[] = {
        [NSOperationQueue class],
        [NSOperation class],
        [NSURLConnection class],
        [NSMutableArray class],
        [NSString class],
        [NSFileManager class],
        [NSURL class],
        [NSData class],
        [UIApplication class],
        [UIWindow class],
        [UIViewController class],
        [UINavigationItem class],
        [UIView class],
        [UIDevice class],
        [UILabel class],
        [UIImage class],
        [UIScreen class],
        [UIButton class],
        [UIImagePickerController class]
    };
    for (NSUInteger index = 0; index < sizeof(classes) / sizeof(classes[0]); index++)
        LightGramIOS3InstallFallbackMethods(classes[index]);
}

@end
