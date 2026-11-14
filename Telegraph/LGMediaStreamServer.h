#import <Foundation/Foundation.h>

#import "LGMediaFetchSession.h"

@interface LGMediaStream : NSObject

@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic, strong, readonly) LGMediaFetchSession *session;

- (int64_t)size;
- (double)downloadRate;
- (bool)isComplete;
- (void)invalidate;

@end

@interface LGMediaStreamServer : NSObject

+ (LGMediaStreamServer *)sharedServer;

- (LGMediaStream *)streamWithDescriptor:(LGMediaFetchDescriptor *)descriptor publishPath:(NSString *)publishPath mimeType:(NSString *)mimeType pathExtension:(NSString *)pathExtension;

@end
