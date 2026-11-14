#import <Foundation/Foundation.h>
#import "LGUserItem.h"
@interface LGCallItem : NSObject
@property (nonatomic, retain) LGUserItem *user;
@property (nonatomic, copy) NSString *statusText;
@property (nonatomic, copy) NSString *dateText;
@property (nonatomic) BOOL outgoing;
@end
