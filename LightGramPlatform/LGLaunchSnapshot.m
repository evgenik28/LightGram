#import "LGLaunchSnapshot.h"

#import <QuartzCore/QuartzCore.h>

enum
{
    LGLaunchSnapshotMagic = 0x534c474f,
    LGLaunchSnapshotVersion = 1,
    LGLaunchSnapshotMaxDimension = 4096
};

typedef struct
{
    uint32_t magic;
    uint32_t version;
    uint32_t width;
    uint32_t height;
    uint32_t bytesPerRow;
    uint32_t identityLength;
} LGLaunchSnapshotHeader;

static CGFloat LGLaunchSnapshotScale(void)
{
    UIScreen *screen = [UIScreen mainScreen];
    if ([screen respondsToSelector:@selector(scale)])
        return MAX((CGFloat)1.0f, screen.scale);
    return 1.0f;
}

static CGBitmapInfo LGLaunchSnapshotBitmapInfo(void)
{
    return (CGBitmapInfo)kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little;
}

BOOL LGLaunchSnapshotCapture(UIView *view, NSString *path, NSString *identity)
{
    if (view == nil || path.length == 0 || identity.length == 0)
        return NO;

    CGFloat scale = LGLaunchSnapshotScale();
    CGSize size = view.bounds.size;
    size_t width = (size_t)(size.width * scale);
    size_t height = (size_t)(size.height * scale);
    if (width == 0 || height == 0 || width > LGLaunchSnapshotMaxDimension || height > LGLaunchSnapshotMaxDimension)
        return NO;

    NSData *identityData = [identity dataUsingEncoding:NSUTF8StringEncoding];
    size_t bytesPerRow = width * 4;
    size_t headerLength = sizeof(LGLaunchSnapshotHeader) + identityData.length;
    NSMutableData *data = [[NSMutableData alloc] initWithLength:headerLength + bytesPerRow * height];
    if (data == nil)
        return NO;

    LGLaunchSnapshotHeader header = { LGLaunchSnapshotMagic, LGLaunchSnapshotVersion, (uint32_t)width, (uint32_t)height, (uint32_t)bytesPerRow, (uint32_t)identityData.length };
    uint8_t *bytes = (uint8_t *)[data mutableBytes];
    memcpy(bytes, &header, sizeof(header));
    memcpy(bytes + sizeof(header), identityData.bytes, identityData.length);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(bytes + headerLength, width, height, 8, bytesPerRow, colorSpace, LGLaunchSnapshotBitmapInfo());
    CGColorSpaceRelease(colorSpace);
    if (context == NULL)
        return NO;

    CGContextTranslateCTM(context, 0.0f, (CGFloat)height);
    CGContextScaleCTM(context, scale, -scale);
    [view.layer renderInContext:context];
    CGContextRelease(context);

    return [data writeToFile:path atomically:YES];
}

static void LGLaunchSnapshotReleaseData(void *info, __unused const void *data, __unused size_t size)
{
    CFRelease(info);
}

UIView *LGLaunchSnapshotCreateView(NSString *path, NSString *identity, CGRect frame)
{
    if (path.length == 0 || identity.length == 0)
        return nil;

    NSData *data = [[NSData alloc] initWithContentsOfFile:path options:0 error:NULL];
    if (data.length < sizeof(LGLaunchSnapshotHeader))
        return nil;

    LGLaunchSnapshotHeader header;
    memcpy(&header, data.bytes, sizeof(header));
    if (header.magic != LGLaunchSnapshotMagic || header.version != LGLaunchSnapshotVersion || header.width == 0 || header.height == 0 || header.width > LGLaunchSnapshotMaxDimension || header.height > LGLaunchSnapshotMaxDimension || header.bytesPerRow < header.width * 4)
        return nil;

    NSData *identityData = [identity dataUsingEncoding:NSUTF8StringEncoding];
    size_t headerLength = sizeof(header) + header.identityLength;
    if (header.identityLength != identityData.length || data.length != headerLength + (size_t)header.bytesPerRow * header.height || memcmp((const uint8_t *)data.bytes + sizeof(header), identityData.bytes, identityData.length) != 0)
        return nil;

    CGFloat scale = LGLaunchSnapshotScale();
    if ((size_t)(frame.size.width * scale) != header.width || (size_t)(frame.size.height * scale) != header.height)
        return nil;

    CFDataRef retainedData = (__bridge_retained CFDataRef)data;
    CGDataProviderRef provider = CGDataProviderCreateWithData((void *)retainedData, (const uint8_t *)data.bytes + headerLength, (size_t)header.bytesPerRow * header.height, LGLaunchSnapshotReleaseData);
    if (provider == NULL)
    {
        CFRelease(retainedData);
        return nil;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(header.width, header.height, 8, 32, header.bytesPerRow, colorSpace, LGLaunchSnapshotBitmapInfo(), provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    if (image == NULL)
        return nil;

    UIView *view = [[UIView alloc] initWithFrame:frame];
    view.opaque = YES;
    view.layer.contents = (__bridge id)image;
    CGImageRelease(image);
    return view;
}
