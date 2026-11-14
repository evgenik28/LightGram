#import <UIKit/UIKit.h>

@class LGMemoryCache;

@interface LGAssets : NSObject
{
    LGMemoryCache *_imageCache;
}
@property (nonatomic, copy) NSString *resourcePrefix;
- (UIImage *)imageNamed:(NSString *)name;
- (UIImage *)imageNamed:(NSString *)name inDirectory:(NSString *)directory;
- (UIImage *)uncachedImageNamed:(NSString *)name inDirectory:(NSString *)directory;
- (UIImage *)uncachedImageNamed:(NSString *)name inDirectory:(NSString *)directory maximumPixelSize:(size_t)maximumPixelSize;
- (UIImage *)resizableImageNamed:(NSString *)name leftCap:(NSInteger)leftCap topCap:(NSInteger)topCap;
- (UIImage *)resizableImageNamed:(NSString *)name inDirectory:(NSString *)directory leftCap:(NSInteger)leftCap topCap:(NSInteger)topCap;
@end
