#import <Foundation/Foundation.h>
#import <stdio.h>

extern const ssize_t LGMediaStreamReaderInterrupted;

@class LGMediaStream;

@interface LGMediaStreamReader : NSObject

@property (nonatomic, strong, readonly) LGMediaStream *stream;
@property (atomic) bool blocking;

- (instancetype)initWithStream:(LGMediaStream *)stream;

- (int64_t)size;
- (int64_t)position;
- (int64_t)availableAhead;
- (bool)hasBufferedAhead:(int64_t)length;
- (bool)isFailed;

- (ssize_t)read:(void *)buffer length:(size_t)length;
- (bool)seekToOffset:(int64_t)offset;
- (bool)waitForRangeFrom:(int64_t)start length:(int64_t)length;

- (FILE *)openFile;
- (void)cancel;
- (void)interrupt;

@end
