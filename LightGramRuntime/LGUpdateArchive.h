#import <Foundation/Foundation.h>

typedef enum {
    LGUpdateArchiveStatusOK = 0,
    LGUpdateArchiveStatusIO,
    LGUpdateArchiveStatusFormat,
    LGUpdateArchiveStatusUnsupported,
    LGUpdateArchiveStatusUnsafeEntry,
    LGUpdateArchiveStatusLimit,
    LGUpdateArchiveStatusChecksum,
    LGUpdateArchiveStatusNoSpace,
    LGUpdateArchiveStatusNotWritable,
    LGUpdateArchiveStatusCancelled
} LGUpdateArchiveStatus;

@interface LGUpdateArchive : NSObject

+ (LGUpdateArchiveStatus)extractApplicationFromArchiveAtPath:(NSString *)archivePath toDirectory:(NSString *)directory isCancelled:(bool (^)(void))isCancelled progress:(void (^)(uint64_t completed, uint64_t total))progress;
+ (LGUpdateArchiveStatus)replaceBundleAtPath:(NSString *)bundlePath withStagedBundleAtPath:(NSString *)stagedPath executableName:(NSString *)executableName progress:(void (^)(uint64_t completed, uint64_t total))progress;
+ (LGUpdateArchiveStatus)prepareDirectoryAtPath:(NSString *)path;
+ (void)removeItemAtPath:(NSString *)path;

@end
