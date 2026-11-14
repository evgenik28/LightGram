#import "LGChannelInfoController.h"
#import "../Core/LGTheme.h"
#import "../Core/LGPalette.h"
@implementation LGChannelInfoController
- (void)loadView { UIView *view = [[UIView alloc] initWithFrame:CGRectZero]; view.backgroundColor = [LGTheme currentTheme].palette.backgroundColor; self.view = view; }
@end
