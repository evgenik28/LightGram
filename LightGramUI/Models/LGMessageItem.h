#import <Foundation/Foundation.h>
@interface LGMessageItem : NSObject
@property (nonatomic) int64_t messageId;
@property (nonatomic) int64_t peerId;
@property (nonatomic, copy) NSString *text;
@property (nonatomic) BOOL outgoing;
@property (nonatomic) NSInteger deliveryState;
@end
