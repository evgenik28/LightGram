#import <Foundation/Foundation.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"
#import "LGMediaFileSource.h"

@class TLInputFileLocation;
@class TGMediaOriginInfo;

typedef enum {
    LGMediaFetchPriorityBackground = 0,
    LGMediaFetchPriorityDownload = 1,
    LGMediaFetchPriorityInteractive = 2,
    LGMediaFetchPriorityPlayback = 3
} LGMediaFetchPriority;

@interface LGMediaFetchDescriptor : NSObject

@property (nonatomic, strong) TLInputFileLocation *location;
@property (nonatomic) NSInteger datacenterId;
@property (nonatomic) int64_t size;
@property (nonatomic) int64_t decryptedSize;
@property (nonatomic, strong) NSData *encryptionKey;
@property (nonatomic, strong) NSData *encryptionIv;
@property (nonatomic) TGNetworkMediaTypeTag mediaTypeTag;
@property (nonatomic, strong) TGMediaOriginInfo *originInfo;
@property (nonatomic) int64_t identifier;
@property (nonatomic, strong) NSString *storePath;
@property (nonatomic) int64_t sizeLimit;
@property (nonatomic) int32_t preferredPartSize;

- (NSString *)resourceKey;

@end

@interface LGMediaFetchObserver : NSObject

@property (nonatomic) bool wantsData;
@property (nonatomic, copy) void (^progress)(float progress);
@property (nonatomic, copy) void (^completed)(NSString *path, NSData *data);
@property (nonatomic, copy) void (^failed)(void);
@property (nonatomic, copy) void (^updated)(void);

@end

@interface LGMediaFetchSession : NSObject

@property (nonatomic, strong, readonly) LGMediaFetchDescriptor *descriptor;

+ (LGMediaFetchSession *)acquireSessionForDescriptor:(LGMediaFetchDescriptor *)descriptor;
+ (void)removeStalePartialFilesInDirectories:(NSArray *)directories;
- (void)relinquish;

- (id)addObserver:(LGMediaFetchObserver *)observer;
- (void)removeObserver:(id)token;
- (void)addPublishPath:(NSString *)path;

- (id)addDemandFrom:(int64_t)start to:(int64_t)end priority:(LGMediaFetchPriority)priority;
- (void)updateDemand:(id)token from:(int64_t)start to:(int64_t)end priority:(LGMediaFetchPriority)priority;
- (void)removeDemand:(id)token;

- (int64_t)size;
- (float)progress;
- (double)downloadRate;
- (bool)isComplete;
- (int64_t)availableLengthAtOffset:(int64_t)offset;
- (ssize_t)readAtOffset:(int64_t)offset buffer:(uint8_t *)buffer length:(size_t)length;

@end

SSignal *LGMediaFetchSequentialSignal(LGMediaFetchDescriptor *descriptor, int64_t start, int64_t end, void (^progress)(float progress));
