#import <Foundation/Foundation.h>
#import "LGUserItem.h"
@interface LGMemberItem : NSObject
@property (nonatomic, retain) LGUserItem *user;
@property (nonatomic, copy) NSString *roleText;
@end
