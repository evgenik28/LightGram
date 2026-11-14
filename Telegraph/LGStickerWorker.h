#import <Foundation/Foundation.h>

@interface LGStickerWorker : NSObject

+ (LGStickerWorker *)preparationWorker;
+ (LGStickerWorker *)auxiliaryWorker;

- (void)perform:(dispatch_block_t)block;

@end
