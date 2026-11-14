#import "LGContactsController.h"
#import "../Core/LGTheme.h"
#import "../Core/LGPalette.h"
@implementation LGContactsController
- (void)loadView { UIView *view = [[UIView alloc] initWithFrame:CGRectZero]; view.backgroundColor = [LGTheme currentTheme].palette.backgroundColor; self.view = view; }
@end
