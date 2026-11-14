#import "LGMediaFetchSession.h"

#import <QuartzCore/QuartzCore.h>
#import <fcntl.h>
#import <pthread.h>
#import <sys/stat.h>
#import <unistd.h>

#import "LGMediaStore.h"
#import "TL/TLMetaScheme.h"
#import "TGNetworkTypeManager.h"

#import "../submodules/MtProtoKit/MTProtoKit/MTEncryption.h"

static const int32_t LGMediaFetchCdnPartSize = 128 * 1024;
static const int32_t LGMediaFetchMinimumPartSize = 4096;
static const NSUInteger LGMediaFetchMaximumRetries = 3;
static const int64_t LGMediaFetchProgressGranularity = 16 * 1024;
static const NSTimeInterval LGMediaFetchRateWindow = 1.5;
#define LGMediaFetchRateSampleCount 32

static const int64_t LGMediaFetchThrottledBudget = 64 * 1024;
static const NSTimeInterval LGMediaFetchPartialFileLifetime = 3.0 * 24.0 * 60.0 * 60.0;
static const int64_t LGMediaFetchPartialFileBudget = 200 * 1024 * 1024;

static NSString *LGMediaFetchPartialBasePath(NSString *path)
{
    NSString *name = [path lastPathComponent];
    for (NSString *suffix in @[@".parts", @".part"])
    {
        NSRange range = [name rangeOfString:suffix options:NSBackwardsSearch];
        if (range.location == NSNotFound || range.location == 0)
            continue;
        NSString *rest = [name substringFromIndex:NSMaxRange(range)];
        bool partial = rest.length == 0 || [rest isEqualToString:@".index"] || [rest isEqualToString:@".info"];
        if (!partial && rest.length > 1 && [rest hasPrefix:@"."])
            partial = [[rest substringFromIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]].length == 0;
        if (partial)
            return [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:[name substringToIndex:NSMaxRange(range)]];
    }
    return nil;
}

static pthread_mutex_t LGMediaFetchRegistryLock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableSetRef LGMediaFetchLiveSessions = NULL;
static NSUInteger LGMediaFetchPlaybackSessionCount = 0;
static NSMutableDictionary *LGMediaFetchRegistry = nil;

@implementation LGMediaFetchDescriptor

- (NSString *)resourceKey
{
    TLInputFileLocation *location = _location;
    if ([location isKindOfClass:[TLInputFileLocation$inputDocumentFileLocation class]])
    {
        TLInputFileLocation$inputDocumentFileLocation *value = (TLInputFileLocation$inputDocumentFileLocation *)location;
        return [[NSString alloc] initWithFormat:@"document:%lld:%@", (long long)value.n_id, value.thumb_size != nil ? value.thumb_size : @""];
    }
    if ([location isKindOfClass:[TLInputFileLocation$inputPhotoFileLocation class]])
    {
        TLInputFileLocation$inputPhotoFileLocation *value = (TLInputFileLocation$inputPhotoFileLocation *)location;
        return [[NSString alloc] initWithFormat:@"photo:%lld:%@", (long long)value.n_id, value.thumb_size != nil ? value.thumb_size : @""];
    }
    if ([location isKindOfClass:[TLInputFileLocation$inputFileLocation class]])
    {
        TLInputFileLocation$inputFileLocation *value = (TLInputFileLocation$inputFileLocation *)location;
        return [[NSString alloc] initWithFormat:@"file:%lld:%d", (long long)value.volume_id, (int)value.local_id];
    }
    if ([location isKindOfClass:[TLInputFileLocation$inputEncryptedFileLocation class]])
    {
        TLInputFileLocation$inputEncryptedFileLocation *value = (TLInputFileLocation$inputEncryptedFileLocation *)location;
        return [[NSString alloc] initWithFormat:@"encrypted:%lld", (long long)value.n_id];
    }
    if ([location isKindOfClass:[TLInputFileLocation$inputPeerPhotoFileLocation class]])
    {
        TLInputFileLocation$inputPeerPhotoFileLocation *value = (TLInputFileLocation$inputPeerPhotoFileLocation *)location;
        return [[NSString alloc] initWithFormat:@"peer-photo:%lld:%lld:%d", (long long)value.peer_id, (long long)value.photo_id, value.big ? 1 : 0];
    }
    if ([location isKindOfClass:[TLInputFileLocation$inputSecureFileLocation class]])
    {
        TLInputFileLocation$inputSecureFileLocation *value = (TLInputFileLocation$inputSecureFileLocation *)location;
        return [[NSString alloc] initWithFormat:@"secure:%lld", (long long)value.n_id];
    }
    return nil;
}

@end

@implementation LGMediaFetchObserver

@end

@interface LGMediaFetchDemand : NSObject

@property (nonatomic) int64_t start;
@property (nonatomic) int64_t end;
@property (nonatomic) LGMediaFetchPriority priority;
@property (nonatomic) NSUInteger order;

@end

@implementation LGMediaFetchDemand

@end

@interface LGMediaFetchPart : NSObject

@property (nonatomic) int64_t offset;
@property (nonatomic) int32_t limit;
@property (nonatomic) int64_t length;
@property (nonatomic) int32_t received;
@property (nonatomic) int32_t total;
@property (nonatomic) LGMediaFetchPriority priority;
@property (nonatomic, strong) id token;

@end

@implementation LGMediaFetchPart

@end

@interface LGMediaFetchSession ()
{
    NSString *_key;
    bool _transient;
    int64_t _transientStart;
    int64_t _transientEnd;
    void (^_transientChunk)(NSData *);
    NSMutableArray *_deliveredChunks;

    NSUInteger _clients;
    bool _started;
    bool _finished;
    bool _failed;
    bool _tornDown;

    pthread_mutex_t _storeLock;
    LGMediaStore *_store;
    int64_t _size;
    NSString *_completedPath;
    int64_t _completedSize;
    int _completedDescriptor;

    NSData *_encryptionKey;
    LGMediaFileSource *_source;
    NSMutableArray *_observers;
    NSMutableArray *_demands;
    NSUInteger _demandOrder;
    NSMutableOrderedSet *_publishPaths;
    NSMutableDictionary *_parts;
    NSMutableDictionary *_retries;
    NSTimeInterval _backoffUntil;
    bool _backoffScheduled;
    int64_t _reportedBytes;
    float _progress;

    int64_t _countedBytes;
    int64_t _receivedBytes;
    NSTimeInterval _rateTimes[LGMediaFetchRateSampleCount];
    int64_t _rateBytes[LGMediaFetchRateSampleCount];
    NSUInteger _rateHead;
    NSUInteger _rateCount;

    bool _live;
    bool _countedAsPlayback;
    bool _throttled;
}

- (void)enqueueDeliveredBytes:(const uint8_t *)bytes length:(size_t)length;

@end

static void LGMediaFetchDecrypt(void *context, void *state, uint8_t *bytes, size_t length)
{
    LGMediaFetchSession *session = (__bridge LGMediaFetchSession *)context;
    NSData *key = session.descriptor.encryptionKey;
    if (length % 16 == 0)
        MTAesDecryptBytesInplaceAndModifyIv(bytes, (NSInteger)length, key, state);
    else
        TGLog(@"[LGMediaFetchSession encrypted data length %d is not aligned]", (int)length);
}

static void LGMediaFetchDeliver(void *context, const uint8_t *bytes, size_t length)
{
    LGMediaFetchSession *session = (__bridge LGMediaFetchSession *)context;
    [session enqueueDeliveredBytes:bytes length:length];
}

@implementation LGMediaFetchSession

+ (LGMediaFetchSession *)acquireSessionForDescriptor:(LGMediaFetchDescriptor *)descriptor
{
    NSString *key = [descriptor resourceKey];
    pthread_mutex_lock(&LGMediaFetchRegistryLock);
    if (LGMediaFetchRegistry == nil)
        LGMediaFetchRegistry = [[NSMutableDictionary alloc] init];
    LGMediaFetchSession *session = key != nil ? LGMediaFetchRegistry[key] : nil;
    bool created = session == nil;
    if (created)
    {
        session = [[LGMediaFetchSession alloc] initWithDescriptor:descriptor key:key];
        if (key != nil)
            LGMediaFetchRegistry[key] = session;
    }
    session->_clients++;
    pthread_mutex_unlock(&LGMediaFetchRegistryLock);

    bool limited = descriptor.sizeLimit > 0;
    dispatch_async(LGMediaFetchQueue(), ^
    {
        if (created)
            [session start];
        else if (!limited)
            [session clearSizeLimit];
    });
    return session;
}

+ (void)removeStalePartialFilesInDirectories:(NSArray *)directories
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        NSMutableDictionary *groups = [[NSMutableDictionary alloc] init];
        void (^collect)(NSString *) = ^(NSString *path)
        {
            NSString *base = LGMediaFetchPartialBasePath(path);
            if (base == nil)
                return;
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:NULL];
            if (attributes == nil || ![[attributes fileType] isEqualToString:NSFileTypeRegular])
                return;
            NSMutableDictionary *group = groups[base];
            if (group == nil)
            {
                group = [[NSMutableDictionary alloc] initWithDictionary:@{@"files": [[NSMutableArray alloc] init], @"size": @0, @"date": [NSDate distantPast]}];
                groups[base] = group;
            }
            [group[@"files"] addObject:path];
            group[@"size"] = @([group[@"size"] longLongValue] + (int64_t)[attributes fileSize]);
            NSDate *date = [attributes fileModificationDate];
            if (date != nil && [date compare:group[@"date"]] == NSOrderedDescending)
                group[@"date"] = date;
        };
        for (NSString *directory in directories)
        {
            for (NSString *name in [fileManager contentsOfDirectoryAtPath:directory error:NULL])
            {
                NSString *path = [directory stringByAppendingPathComponent:name];
                BOOL isDirectory = NO;
                if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory])
                    continue;
                if (isDirectory)
                {
                    for (NSString *child in [fileManager contentsOfDirectoryAtPath:path error:NULL])
                        collect([path stringByAppendingPathComponent:child]);
                }
                else
                    collect(path);
            }
        }
        if (groups.count == 0)
            return;

        dispatch_async(LGMediaFetchQueue(), ^
        {
            NSMutableSet *liveStorePaths = [[NSMutableSet alloc] init];
            if (LGMediaFetchLiveSessions != NULL)
            {
                CFIndex count = CFSetGetCount(LGMediaFetchLiveSessions);
                const void **values = count > 0 ? (const void **)malloc(sizeof(void *) * (size_t)count) : NULL;
                if (values != NULL)
                {
                    CFSetGetValues(LGMediaFetchLiveSessions, values);
                    for (CFIndex i = 0; i < count; i++)
                    {
                        NSString *storePath = ((__bridge LGMediaFetchSession *)values[i]).descriptor.storePath;
                        if (storePath != nil)
                            [liveStorePaths addObject:storePath];
                    }
                    free(values);
                }
            }

            NSDate *expiration = [NSDate dateWithTimeIntervalSinceNow:-LGMediaFetchPartialFileLifetime];
            NSMutableArray *retained = [[NSMutableArray alloc] init];
            int64_t retainedSize = 0;
            NSMutableArray *removals = [[NSMutableArray alloc] init];
            for (NSString *base in groups)
            {
                if ([liveStorePaths containsObject:base])
                    continue;
                NSDictionary *group = groups[base];
                if ([group[@"date"] compare:expiration] == NSOrderedAscending)
                    [removals addObject:group];
                else
                {
                    [retained addObject:group];
                    retainedSize += [group[@"size"] longLongValue];
                }
            }
            [retained sortUsingComparator:^NSComparisonResult(NSDictionary *first, NSDictionary *second)
            {
                return [first[@"date"] compare:second[@"date"]];
            }];
            for (NSDictionary *group in retained)
            {
                if (retainedSize <= LGMediaFetchPartialFileBudget)
                    break;
                retainedSize -= [group[@"size"] longLongValue];
                [removals addObject:group];
            }
            for (NSDictionary *group in removals)
            {
                for (NSString *path in group[@"files"])
                    unlink(path.fileSystemRepresentation);
            }
        });
    });
}

- (instancetype)initWithDescriptor:(LGMediaFetchDescriptor *)descriptor key:(NSString *)key
{
    self = [super init];
    if (self != nil)
    {
        _descriptor = descriptor;
        _key = key;
        _size = descriptor.size;
        _completedDescriptor = -1;
        pthread_mutex_init(&_storeLock, NULL);
        _observers = [[NSMutableArray alloc] init];
        _demands = [[NSMutableArray alloc] init];
        _publishPaths = [[NSMutableOrderedSet alloc] init];
        _parts = [[NSMutableDictionary alloc] init];
        _retries = [[NSMutableDictionary alloc] init];
        if (descriptor.encryptionKey.length == 32 && descriptor.encryptionIv.length == 32)
            _encryptionKey = descriptor.encryptionKey;
    }
    return self;
}

- (instancetype)initTransientWithDescriptor:(LGMediaFetchDescriptor *)descriptor start:(int64_t)start end:(int64_t)end chunk:(void (^)(NSData *))chunk
{
    self = [self initWithDescriptor:descriptor key:nil];
    if (self != nil)
    {
        _transient = true;
        _transientStart = start;
        _transientEnd = end;
        _transientChunk = [chunk copy];
        _deliveredChunks = [[NSMutableArray alloc] init];
        _clients = 1;
    }
    return self;
}

- (void)dealloc
{
    if (_store != NULL)
        LGMediaStoreDestroy(_store);
    if (_completedDescriptor >= 0)
        close(_completedDescriptor);
    pthread_mutex_destroy(&_storeLock);
}

- (void)relinquish
{
    dispatch_async(LGMediaFetchQueue(), ^
    {
        pthread_mutex_lock(&LGMediaFetchRegistryLock);
        if (_clients > 0)
            _clients--;
        bool idle = _clients == 0;
        if (idle)
            [self unregisterLocked];
        pthread_mutex_unlock(&LGMediaFetchRegistryLock);
        if (idle)
            [self teardown];
    });
}

- (void)unregisterLocked
{
    if (_key != nil && LGMediaFetchRegistry[_key] == self)
        [LGMediaFetchRegistry removeObjectForKey:_key];
}

- (void)unregister
{
    pthread_mutex_lock(&LGMediaFetchRegistryLock);
    [self unregisterLocked];
    pthread_mutex_unlock(&LGMediaFetchRegistryLock);
}

- (void)registerLive
{
    if (_live)
        return;
    if (LGMediaFetchLiveSessions == NULL)
        LGMediaFetchLiveSessions = CFSetCreateMutable(kCFAllocatorDefault, 0, NULL);
    CFSetAddValue(LGMediaFetchLiveSessions, (__bridge const void *)self);
    _live = true;
}

- (void)unregisterLive
{
    if (_live)
    {
        CFSetRemoveValue(LGMediaFetchLiveSessions, (__bridge const void *)self);
        _live = false;
    }
    [self setCountedAsPlayback:false];
}

- (void)setCountedAsPlayback:(bool)playback
{
    if (_countedAsPlayback == playback)
        return;
    _countedAsPlayback = playback;
    if (playback)
    {
        LGMediaFetchPlaybackSessionCount++;
        return;
    }
    if (LGMediaFetchPlaybackSessionCount > 0)
        LGMediaFetchPlaybackSessionCount--;
    if (LGMediaFetchPlaybackSessionCount == 0 && LGMediaFetchLiveSessions != NULL)
    {
        CFIndex count = CFSetGetCount(LGMediaFetchLiveSessions);
        if (count == 0)
            return;
        const void **values = (const void **)malloc(sizeof(void *) * (size_t)count);
        if (values == NULL)
            return;
        CFSetGetValues(LGMediaFetchLiveSessions, values);
        NSMutableArray *sessions = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)count];
        for (CFIndex i = 0; i < count; i++)
            [sessions addObject:(__bridge LGMediaFetchSession *)values[i]];
        free(values);
        dispatch_async(LGMediaFetchQueue(), ^
        {
            for (LGMediaFetchSession *session in sessions)
                [session pump];
        });
    }
}

- (void)updatePlaybackState
{
    bool playback = false;
    for (LGMediaFetchDemand *demand in _demands)
    {
        if (demand.priority >= LGMediaFetchPriorityPlayback)
        {
            playback = true;
            break;
        }
    }
    [self setCountedAsPlayback:playback && _live];
}

- (void)start
{
    if (_started || _tornDown)
        return;
    _started = true;
    [self registerLive];

    NSString *storePath = _descriptor.storePath;
    LGMediaStoreConfiguration configuration;
    memset(&configuration, 0, sizeof(configuration));
    configuration.context = (__bridge void *)self;
    configuration.memoryWindow = 512 * 1024;
    configuration.sequential = _transient || _encryptionKey != nil || _descriptor.size <= 0 || _descriptor.sizeLimit > 0;
    if (_encryptionKey != nil)
    {
        configuration.stateLength = 32;
        configuration.initialState = _descriptor.encryptionIv.bytes;
        configuration.transform = LGMediaFetchDecrypt;
    }
    if (_transient)
    {
        int64_t end = _transientEnd >= INT32_MAX ? 0 : _transientEnd;
        if (_descriptor.size > 0)
            end = end > 0 ? MIN(end, _descriptor.size) : _descriptor.size;
        configuration.size = end;
        configuration.origin = _transientStart;
        configuration.deliver = LGMediaFetchDeliver;
    }
    else
    {
        configuration.size = _descriptor.size;
        [[NSFileManager defaultManager] removeItemAtPath:[storePath stringByAppendingString:@".info"] error:NULL];
    }

    LGMediaStore *store = LGMediaStoreCreate(_transient ? NULL : storePath.fileSystemRepresentation, &configuration);
    if (store == NULL || (!_transient && storePath.length == 0))
    {
        if (store != NULL)
            LGMediaStoreDestroy(store);
        [self fail];
        return;
    }
    pthread_mutex_lock(&_storeLock);
    _store = store;
    _size = LGMediaStoreSize(store);
    pthread_mutex_unlock(&_storeLock);

    if (LGMediaStoreIsComplete(store))
    {
        [self complete];
        return;
    }

    _source = [[LGMediaFileSource alloc] initWithLocation:_descriptor.location datacenterId:_descriptor.datacenterId size:_size mediaTypeTag:_descriptor.mediaTypeTag originInfo:_descriptor.originInfo identifier:_descriptor.identifier];
    __weak LGMediaFetchSession *weakSelf = self;
    _source.availabilityChanged = ^
    {
        [weakSelf pump];
    };
    [self reportProgress:true];
    [self pump];
}

- (void)clearSizeLimit
{
    _descriptor.sizeLimit = 0;
}

- (void)enqueueDeliveredBytes:(const uint8_t *)bytes length:(size_t)length
{
    [_deliveredChunks addObject:[[NSData alloc] initWithBytes:bytes length:length]];
}

- (void)flushDeliveredChunks
{
    if (_deliveredChunks.count == 0)
        return;
    NSArray *chunks = [_deliveredChunks copy];
    [_deliveredChunks removeAllObjects];
    for (NSData *chunk in chunks)
    {
        if (_transientChunk != nil)
            _transientChunk(chunk);
    }
}

#pragma mark - Clients

- (id)addObserver:(LGMediaFetchObserver *)observer
{
    dispatch_async(LGMediaFetchQueue(), ^
    {
        if (_tornDown)
            return;
        if (_finished)
        {
            NSData *data = observer.wantsData && _completedPath != nil ? [[NSData alloc] initWithContentsOfFile:_completedPath] : nil;
            if (observer.completed != nil)
                observer.completed(_completedPath, data);
            return;
        }
        if (_failed)
        {
            if (observer.failed != nil)
                observer.failed();
            return;
        }
        [_observers addObject:observer];
        if (_started && _progress > 0.0f && observer.progress != nil)
            observer.progress(_progress);
    });
    return observer;
}

- (void)removeObserver:(id)token
{
    dispatch_async(LGMediaFetchQueue(), ^
    {
        [_observers removeObjectIdenticalTo:token];
    });
}

- (void)addPublishPath:(NSString *)path
{
    if (path.length == 0)
        return;
    dispatch_async(LGMediaFetchQueue(), ^
    {
        if (_finished)
        {
            if (_completedPath != nil && ![path isEqualToString:_completedPath])
                [self linkPublishedPath:_completedPath toPath:path];
            return;
        }
        [_publishPaths addObject:path];
    });
}

- (id)addDemandFrom:(int64_t)start to:(int64_t)end priority:(LGMediaFetchPriority)priority
{
    LGMediaFetchDemand *demand = [[LGMediaFetchDemand alloc] init];
    demand.start = MAX(0, start);
    demand.end = end;
    demand.priority = priority;
    dispatch_async(LGMediaFetchQueue(), ^
    {
        if (_tornDown)
            return;
        demand.order = _demandOrder++;
        [_demands addObject:demand];
        [self pump];
    });
    return demand;
}

- (void)updateDemand:(id)token from:(int64_t)start to:(int64_t)end priority:(LGMediaFetchPriority)priority
{
    LGMediaFetchDemand *demand = token;
    dispatch_async(LGMediaFetchQueue(), ^
    {
        demand.start = MAX(0, start);
        demand.end = end;
        demand.priority = priority;
        [self pump];
    });
}

- (void)removeDemand:(id)token
{
    dispatch_async(LGMediaFetchQueue(), ^
    {
        [_demands removeObjectIdenticalTo:token];
        [self updatePlaybackState];
    });
}

#pragma mark - Reading

- (int64_t)logicalSizeLocked
{
    if (_completedPath != nil)
        return _completedSize;
    int64_t decryptedSize = _descriptor.decryptedSize;
    if (_encryptionKey != nil && decryptedSize > 0 && (_size == 0 || decryptedSize < _size))
        return decryptedSize;
    return _size;
}

- (int64_t)size
{
    pthread_mutex_lock(&_storeLock);
    int64_t size = [self logicalSizeLocked];
    pthread_mutex_unlock(&_storeLock);
    return size;
}

- (float)progress
{
    pthread_mutex_lock(&_storeLock);
    float progress = _completedPath != nil ? 1.0f : _progress;
    pthread_mutex_unlock(&_storeLock);
    return progress;
}

- (bool)isComplete
{
    pthread_mutex_lock(&_storeLock);
    bool complete = _completedPath != nil;
    pthread_mutex_unlock(&_storeLock);
    return complete;
}

- (double)downloadRate
{
    pthread_mutex_lock(&_storeLock);
    double rate = 0.0;
    if (_rateCount != 0)
    {
        NSTimeInterval now = CACurrentMediaTime();
        NSUInteger newest = (_rateHead + LGMediaFetchRateSampleCount - 1) % LGMediaFetchRateSampleCount;
        NSUInteger oldest = newest;
        for (NSUInteger i = 1; i < _rateCount; i++)
        {
            NSUInteger index = (newest + LGMediaFetchRateSampleCount - i) % LGMediaFetchRateSampleCount;
            oldest = index;
            if (now - _rateTimes[index] >= LGMediaFetchRateWindow)
                break;
        }
        NSTimeInterval elapsed = MAX(now - _rateTimes[oldest], 0.25);
        if (oldest != newest && now - _rateTimes[newest] < LGMediaFetchRateWindow * 2.0)
            rate = (double)(_rateBytes[newest] - _rateBytes[oldest]) / elapsed;
    }
    pthread_mutex_unlock(&_storeLock);
    return rate;
}

- (void)recordRateSample:(int64_t)currentBytes
{
    if (currentBytes > _countedBytes)
        _receivedBytes += currentBytes - _countedBytes;
    _countedBytes = currentBytes;
    NSTimeInterval now = CACurrentMediaTime();
    pthread_mutex_lock(&_storeLock);
    NSUInteger last = (_rateHead + LGMediaFetchRateSampleCount - 1) % LGMediaFetchRateSampleCount;
    if (_rateCount != 0 && now - _rateTimes[last] < 0.05)
        _rateBytes[last] = _receivedBytes;
    else
    {
        _rateTimes[_rateHead] = now;
        _rateBytes[_rateHead] = _receivedBytes;
        _rateHead = (_rateHead + 1) % LGMediaFetchRateSampleCount;
        if (_rateCount < LGMediaFetchRateSampleCount)
            _rateCount++;
    }
    pthread_mutex_unlock(&_storeLock);
}

- (int64_t)availableLengthAtOffset:(int64_t)offset
{
    pthread_mutex_lock(&_storeLock);
    int64_t result = 0;
    int64_t size = [self logicalSizeLocked];
    if (_store != NULL)
        result = LGMediaStoreAvailableLength(_store, offset);
    else if (_completedPath != nil)
        result = MAX(0, _completedSize - offset);
    if (size > 0)
        result = MAX(0, MIN(result, size - offset));
    pthread_mutex_unlock(&_storeLock);
    return result;
}

- (ssize_t)readAtOffset:(int64_t)offset buffer:(uint8_t *)buffer length:(size_t)length
{
    pthread_mutex_lock(&_storeLock);
    ssize_t result = 0;
    int64_t size = [self logicalSizeLocked];
    if (size > 0)
        length = (size_t)MAX(0, MIN((int64_t)length, size - offset));
    if (length != 0)
    {
        if (_store != NULL)
            result = LGMediaStoreRead(_store, offset, buffer, length);
        else if (_completedPath != nil)
        {
            if (_completedDescriptor < 0)
                _completedDescriptor = open(_completedPath.fileSystemRepresentation, O_RDONLY);
            result = _completedDescriptor >= 0 ? pread(_completedDescriptor, buffer, length, (off_t)offset) : -1;
        }
    }
    pthread_mutex_unlock(&_storeLock);
    return result;
}

#pragma mark - Scheduling

- (int32_t)preferredPartSize:(LGTransferParameters)parameters
{
    if (_throttled && !_source.usesCdn)
        return (int32_t)LGMediaFetchThrottledBudget;
    int32_t preferred = _descriptor.preferredPartSize;
    if (preferred >= LGMediaFetchMinimumPartSize && preferred <= 1024 * 1024 && (preferred & (preferred - 1)) == 0 && !_source.usesCdn)
        return preferred;
    if (_descriptor.sizeLimit > 0)
        return 512 * 1024;
    if (_descriptor.mediaTypeTag == TGNetworkMediaTypeTagImage && _size > 0 && _size <= 512 * 1024 && !_source.usesCdn && _encryptionKey == nil)
        return 512 * 1024;
    if (_source.usesCdn || _encryptionKey != nil || _size <= 0)
        return 128 * 1024;
    return (int32_t)parameters.partSize;
}

- (LGMediaFetchPart *)partCoveringOffset:(int64_t)offset
{
    for (LGMediaFetchPart *part in [_parts allValues])
    {
        if (part.offset <= offset && offset < part.offset + part.limit)
            return part;
    }
    return nil;
}

- (int64_t)nextPartStartAfter:(int64_t)offset
{
    int64_t result = INT64_MAX;
    for (LGMediaFetchPart *part in [_parts allValues])
    {
        if (part.offset > offset && part.offset < result)
            result = part.offset;
    }
    return result;
}

- (LGMediaFetchPart *)partAtOffset:(int64_t)offset priority:(LGMediaFetchPriority)priority parameters:(LGTransferParameters)parameters sequential:(bool)sequential
{
    int32_t partSize = 0;
    if (_source.usesCdn)
        partSize = LGMediaFetchCdnPartSize;
    else
    {
        partSize = [self preferredPartSize:parameters];
        while (partSize > LGMediaFetchMinimumPartSize && offset % partSize != 0)
            partSize /= 2;
        if (!sequential)
        {
            int64_t needed = MAX((int64_t)LGMediaFetchMinimumPartSize, LGMediaStoreMissingRunEnd(_store, offset, offset + partSize) - offset);
            while (partSize > LGMediaFetchMinimumPartSize && partSize / 2 >= needed)
                partSize /= 2;
            int64_t hardEnd = [self nextPartStartAfter:offset];
            while (partSize > LGMediaFetchMinimumPartSize && offset + partSize > hardEnd)
                partSize /= 2;
        }
    }
    LGMediaFetchPart *part = [[LGMediaFetchPart alloc] init];
    part.offset = offset;
    part.limit = partSize;
    part.length = _size > 0 ? MIN((int64_t)partSize, _size - offset) : partSize;
    part.priority = priority;
    return part;
}

- (NSArray *)orderedDemands
{
    return [_demands sortedArrayUsingComparator:^NSComparisonResult(LGMediaFetchDemand *first, LGMediaFetchDemand *second)
    {
        if (first.priority != second.priority)
            return first.priority > second.priority ? NSOrderedAscending : NSOrderedDescending;
        if (first.order != second.order)
            return first.order < second.order ? NSOrderedAscending : NSOrderedDescending;
        return NSOrderedSame;
    }];
}

- (LGMediaFetchPart *)nextPartCandidate:(LGTransferParameters)parameters sequential:(bool)sequential demands:(NSArray *)demands
{
    if (sequential)
    {
        int64_t offset = LGMediaStorePrefix(_store);
        for (LGMediaFetchPart *part in [_parts allValues])
            offset = MAX(offset, part.offset + part.limit);
        if (_size > 0 && offset >= _size)
            return nil;
        if (_transient && _transientEnd < INT32_MAX && offset >= _transientEnd)
            return nil;
        if (_descriptor.sizeLimit > 0 && offset >= _descriptor.sizeLimit)
            return nil;
        LGMediaFetchDemand *top = demands.firstObject;
        return [self partAtOffset:offset priority:top.priority parameters:parameters sequential:true];
    }

    int64_t alignment = _source.usesCdn ? LGMediaFetchCdnPartSize : LGMediaFetchMinimumPartSize;
    for (LGMediaFetchDemand *demand in demands)
    {
        int64_t cursor = demand.start;
        while (true)
        {
            int64_t missing = LGMediaStoreFirstMissing(_store, cursor, demand.end);
            if (missing < 0)
                break;
            missing -= missing % alignment;
            LGMediaFetchPart *covering = [self partCoveringOffset:missing];
            if (covering != nil)
            {
                cursor = MAX(cursor + LGMediaFetchMinimumPartSize, covering.offset + covering.limit);
                continue;
            }
            return [self partAtOffset:missing priority:demand.priority parameters:parameters sequential:false];
        }
    }
    return nil;
}

- (bool)preemptFor:(LGMediaFetchPart *)candidate
{
    LGMediaFetchPart *victim = nil;
    for (LGMediaFetchPart *part in [_parts allValues])
    {
        if (part.priority >= candidate.priority || part.received * 2 > part.limit)
            continue;
        if (victim == nil || part.priority < victim.priority || (part.priority == victim.priority && part.received < victim.received))
            victim = part;
    }
    if (victim == nil)
        return false;
    [_parts removeObjectForKey:@(victim.offset)];
    [_source cancelPart:victim.token];
    return true;
}

- (int64_t)inFlightBytes
{
    int64_t bytes = 0;
    for (LGMediaFetchPart *part in [_parts allValues])
        bytes += part.limit;
    return bytes;
}

- (void)pump
{
    if (!_started || _finished || _failed || _tornDown || _store == NULL)
        return;
    if (LGMediaStoreIsComplete(_store))
    {
        [self complete];
        return;
    }
    [self updatePlaybackState];
    if (_demands.count == 0 || !_source.available)
        return;
    NSTimeInterval now = CACurrentMediaTime();
    if (now < _backoffUntil)
    {
        [self scheduleBackoffPump];
        return;
    }

    LGTransferParameters parameters = [TGNetworkTypeManager transferParametersForUpload:false];
    bool sequential = LGMediaStoreIsSequential(_store);
    NSUInteger maximumParts = (_size <= 0 || _descriptor.sizeLimit > 0) ? 1 : (NSUInteger)MAX(1, parameters.maximumRequests);
    int64_t budget = MAX((int64_t)LGMediaFetchCdnPartSize, parameters.maximumInFlightBytes);
    LGMediaStoreSetMemoryWindow(_store, MAX((int64_t)512 * 1024, MIN((int64_t)4 * 1024 * 1024, budget * 2)));

    NSArray *demands = [self orderedDemands];
    LGMediaFetchDemand *topDemand = demands.firstObject;
    _throttled = !_countedAsPlayback && LGMediaFetchPlaybackSessionCount > 0 && topDemand.priority < LGMediaFetchPriorityInteractive;
    if (_throttled)
    {
        maximumParts = 1;
        budget = LGMediaFetchThrottledBudget;
    }
    int64_t inFlight = [self inFlightBytes];
    while (!_finished && !_failed)
    {
        LGMediaFetchPart *candidate = [self nextPartCandidate:parameters sequential:sequential demands:demands];
        if (candidate == nil)
            break;
        if (_parts.count >= maximumParts || (inFlight != 0 && inFlight + candidate.limit > budget))
        {
            if (candidate.priority >= LGMediaFetchPriorityPlayback && [self preemptFor:candidate])
            {
                inFlight = [self inFlightBytes];
                continue;
            }
            break;
        }
        if (![self startPart:candidate])
            break;
        inFlight += candidate.limit;
    }
}

- (bool)startPart:(LGMediaFetchPart *)part
{
    __weak LGMediaFetchSession *weakSelf = self;
    __weak LGMediaFetchPart *weakPart = part;
    id token = [_source requestPartAtOffset:part.offset limit:part.limit progress:^(int32_t received, int32_t total)
    {
        LGMediaFetchSession *strongSelf = weakSelf;
        LGMediaFetchPart *strongPart = weakPart;
        if (strongSelf == nil || strongPart == nil)
            return;
        strongPart.received = received;
        strongPart.total = total;
        [strongSelf reportProgress:false];
    } completion:^(LGMediaPartResult result, NSData *data)
    {
        [weakSelf part:part finishedWithResult:result data:data];
    }];
    if (token == nil)
        return false;
    part.token = token;
    _parts[@(part.offset)] = part;
    return true;
}

- (void)scheduleBackoffPump
{
    if (_backoffScheduled)
        return;
    _backoffScheduled = true;
    NSTimeInterval delay = MAX(0.05, _backoffUntil - CACurrentMediaTime());
    __weak LGMediaFetchSession *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), LGMediaFetchQueue(), ^
    {
        LGMediaFetchSession *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_backoffScheduled = false;
        [strongSelf pump];
    });
}

- (void)retryPart:(LGMediaFetchPart *)part
{
    NSNumber *key = @(part.offset);
    NSUInteger count = [_retries[key] unsignedIntegerValue] + 1;
    if (count > LGMediaFetchMaximumRetries)
    {
        [self fail];
        return;
    }
    _retries[key] = @(count);
    _backoffUntil = MAX(_backoffUntil, CACurrentMediaTime() + 0.5 * (double)(1u << (count - 1)));
    [self pump];
}

- (void)part:(LGMediaFetchPart *)part finishedWithResult:(LGMediaPartResult)result data:(NSData *)data
{
    if (_parts[@(part.offset)] != part)
        return;
    [_parts removeObjectForKey:@(part.offset)];
    if (_finished || _failed || _tornDown)
        return;

    switch (result)
    {
        case LGMediaPartResultData:
            [self commitPart:part data:data];
            break;
        case LGMediaPartResultRestart:
            [self pump];
            break;
        case LGMediaPartResultRetry:
            [self retryPart:part];
            break;
        case LGMediaPartResultFailure:
            [self fail];
            break;
    }
}

- (void)commitPart:(LGMediaFetchPart *)part data:(NSData *)data
{
    int64_t length = (int64_t)data.length;
    bool sizeAuthoritative = _descriptor.size > 0;
    if (length == 0)
    {
        if (!sizeAuthoritative && part.offset > 0)
            [self updateSize:part.offset];
        else
        {
            [self retryPart:part];
            return;
        }
    }
    else
    {
        if (!sizeAuthoritative && length < part.limit)
            [self updateSize:part.offset + length];
        int64_t end = part.offset + length;
        bool progressed = end - end % LGMediaStoreBlockSize > part.offset || (_size > 0 && end >= _size);
        if (!LGMediaStoreWrite(_store, part.offset, (const uint8_t *)data.bytes, (size_t)length))
        {
            [self fail];
            return;
        }
        if (_transient)
            [self flushDeliveredChunks];
        LGMediaStoreSynchronize(_store);
        if (!progressed)
        {
            [self retryPart:part];
            return;
        }
        [_retries removeObjectForKey:@(part.offset)];
        for (LGMediaFetchObserver *observer in [_observers copy])
        {
            if (observer.updated != nil)
                observer.updated();
        }
    }

    int64_t limit = _descriptor.sizeLimit;
    if (limit > 0 && !LGMediaStoreIsComplete(_store) && ((_size > 0 && _size > limit) || (_size <= 0 && LGMediaStorePrefix(_store) >= limit)))
    {
        [self fail];
        return;
    }
    [self reportProgress:false];
    [self pump];
}

- (void)updateSize:(int64_t)size
{
    LGMediaStoreSetSize(_store, size);
    pthread_mutex_lock(&_storeLock);
    _size = LGMediaStoreSize(_store);
    pthread_mutex_unlock(&_storeLock);
}

- (void)reportProgress:(bool)force
{
    if (_store == NULL)
        return;
    int64_t base = _transient ? _transientStart - _transientStart % LGMediaStoreBlockSize : 0;
    int64_t present = LGMediaStorePresentBytes(_store) - base;
    int64_t bytes = present;
    int64_t total = _size > 0 ? _size - base : present;
    for (LGMediaFetchPart *part in [_parts allValues])
    {
        bytes += part.received;
        if (_size <= 0)
            total += MAX((int64_t)part.received, (int64_t)(part.total > 0 ? part.total : part.limit));
    }
    [self recordRateSample:bytes];
    if (total <= 0)
        return;
    bytes = MIN(bytes, total);
    if (!force && (bytes <= _reportedBytes || (bytes / LGMediaFetchProgressGranularity == _reportedBytes / LGMediaFetchProgressGranularity && bytes != total)))
        return;
    _reportedBytes = bytes;
    float progress = MIN(1.0f, MAX(0.001f, (float)((double)bytes / (double)total)));
    pthread_mutex_lock(&_storeLock);
    _progress = progress;
    pthread_mutex_unlock(&_storeLock);
    for (LGMediaFetchObserver *observer in [_observers copy])
    {
        if (observer.progress != nil)
            observer.progress(progress);
    }
}

#pragma mark - Completion

- (void)cancelParts
{
    for (LGMediaFetchPart *part in [_parts allValues])
        [_source cancelPart:part.token];
    [_parts removeAllObjects];
}

- (bool)linkPublishedPath:(NSString *)source toPath:(NSString *)path
{
    unlink(path.fileSystemRepresentation);
    if (link(source.fileSystemRepresentation, path.fileSystemRepresentation) == 0)
        return true;
    return [[NSFileManager defaultManager] copyItemAtPath:source toPath:path error:NULL];
}

- (bool)publish
{
    int64_t decryptedSize = _descriptor.decryptedSize;
    int64_t truncation = _encryptionKey != nil && decryptedSize > 0 && decryptedSize < _size ? decryptedSize : 0;
    pthread_mutex_lock(&_storeLock);
    bool finished = LGMediaStoreFinish(_store, truncation);
    LGMediaStoreDestroy(_store);
    _store = NULL;
    pthread_mutex_unlock(&_storeLock);
    if (!finished)
        return false;
    if (_transient)
        return true;

    NSString *source = _descriptor.storePath;
    NSString *primary = _publishPaths.firstObject;
    if (primary != nil && ![primary isEqualToString:source])
    {
        if (rename(source.fileSystemRepresentation, primary.fileSystemRepresentation) != 0)
            return false;
    }
    else
        primary = source;
    for (NSString *path in _publishPaths)
    {
        if (![path isEqualToString:primary] && ![self linkPublishedPath:primary toPath:path])
            return false;
    }

    struct stat value;
    int64_t completedSize = stat(primary.fileSystemRepresentation, &value) == 0 ? (int64_t)value.st_size : 0;
    pthread_mutex_lock(&_storeLock);
    _completedPath = primary;
    _completedSize = completedSize;
    pthread_mutex_unlock(&_storeLock);
    return true;
}

- (void)complete
{
    if (_finished || _failed)
        return;
    _finished = true;
    [self unregisterLive];
    [self cancelParts];
    [_source invalidate];
    _source = nil;
    if (_transient)
        [self flushDeliveredChunks];
    if (![self publish])
    {
        _finished = false;
        [self fail];
        return;
    }
    [self unregister];
    [_demands removeAllObjects];

    NSData *data = nil;
    for (LGMediaFetchObserver *observer in _observers)
    {
        if (observer.wantsData && _completedPath != nil)
        {
            data = [[NSData alloc] initWithContentsOfFile:_completedPath];
            break;
        }
    }
    NSArray *observers = [_observers copy];
    [_observers removeAllObjects];
    for (LGMediaFetchObserver *observer in observers)
    {
        if (observer.completed != nil)
            observer.completed(_completedPath, observer.wantsData ? data : nil);
    }
}

- (void)fail
{
    if (_failed || _finished)
        return;
    _failed = true;
    [self unregisterLive];
    [self cancelParts];
    [_source invalidate];
    _source = nil;
    pthread_mutex_lock(&_storeLock);
    if (_store != NULL)
        LGMediaStoreDestroy(_store);
    _store = NULL;
    pthread_mutex_unlock(&_storeLock);
    [self unregister];
    [_demands removeAllObjects];
    NSArray *observers = [_observers copy];
    [_observers removeAllObjects];
    for (LGMediaFetchObserver *observer in observers)
    {
        if (observer.failed != nil)
            observer.failed();
    }
}

- (void)teardown
{
    if (_tornDown)
        return;
    _tornDown = true;
    [self unregisterLive];
    [self cancelParts];
    [_source invalidate];
    _source = nil;
    pthread_mutex_lock(&_storeLock);
    if (_store != NULL)
        LGMediaStoreDestroy(_store);
    _store = NULL;
    pthread_mutex_unlock(&_storeLock);
    [_observers removeAllObjects];
    [_demands removeAllObjects];
    _transientChunk = nil;
}

@end

SSignal *LGMediaFetchSequentialSignal(LGMediaFetchDescriptor *descriptor, int64_t start, int64_t end, void (^progress)(float progress))
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        LGMediaFetchSession *session = [[LGMediaFetchSession alloc] initTransientWithDescriptor:descriptor start:start end:end chunk:^(NSData *data)
        {
            [subscriber putNext:data];
        }];
        LGMediaFetchObserver *observer = [[LGMediaFetchObserver alloc] init];
        observer.progress = progress;
        observer.completed = ^(__unused NSString *path, __unused NSData *data)
        {
            [subscriber putCompletion];
        };
        observer.failed = ^
        {
            [subscriber putError:[NSError errorWithDomain:@"LGMediaFetch" code:-1 userInfo:nil]];
        };
        dispatch_async(LGMediaFetchQueue(), ^
        {
            [session start];
        });
        [session addObserver:observer];
        [session addDemandFrom:start to:end priority:LGMediaFetchPriorityInteractive];
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [session relinquish];
        }];
    }];
}
