#import "TGLightGramUpdater.h"

#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "LGCoreHTTPSFetch.h"
#import "LGCoreJSON.h"
#import "../LightGramRuntime/LGUpdateArchive.h"
#import "../LightGramPlatform/LGPlatformUIKit.h"

#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <spawn.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

NSString *const TGLightGramUpdaterStateChangedNotification = @"TGLightGramUpdaterStateChangedNotification";

static NSString *const TGLightGramUpdaterRepository = @"evgenik28/LightGram";
static NSString *const TGLightGramUpdaterUniversalMarker = @"armv6-armv7-arm64";
static NSString *const TGLightGramUpdaterLastCheckKey = @"TGLightGramUpdaterLastCheck";
static NSString *const TGLightGramUpdaterStagingName = @".onegram-update";
static NSString *const TGLightGramUpdaterPackageName = @"onegram-update.ipa";
static NSString *const TGLightGramUpdaterInstallEntitlement = @"com.apple.private.mobileinstall.allowedSPI";
static NSString *const TGLightGramUpdaterInstallSPI = @"InstallForLaunchServices";
static const NSTimeInterval TGLightGramUpdaterCheckInterval = 6.0 * 60.0 * 60.0;
static const uint64_t TGLightGramUpdaterMetadataLimit = 2ULL * 1024ULL * 1024ULL;
static const uint64_t TGLightGramUpdaterChecksumLimit = 4096ULL;
static const uint64_t TGLightGramUpdaterPackageLimit = 256ULL * 1024ULL * 1024ULL;
static const uint64_t TGLightGramUpdaterSpaceReserve = 16ULL * 1024ULL * 1024ULL;
static const int TGLightGramUpdaterRedirectLimit = 5;
static const int TGLightGramUpdaterIdleTimeoutSeconds = 30;
static const float TGLightGramUpdaterDownloadShare = 0.6f;
static const float TGLightGramUpdaterExtractShare = 0.35f;

static NSArray *TGLightGramUpdaterVersionComponents(NSString *text)
{
    NSUInteger index = 0;
    while (index < text.length && ([text characterAtIndex:index] == 'v' || [text characterAtIndex:index] == 'V'))
        index++;

    NSUInteger end = index;
    while (end < text.length)
    {
        unichar character = [text characterAtIndex:end];
        if (!((character >= '0' && character <= '9') || character == '.'))
            break;
        end++;
    }

    NSString *numeric = [text substringWithRange:NSMakeRange(index, end - index)];
    NSMutableArray *components = [[NSMutableArray alloc] init];
    for (NSString *component in [numeric componentsSeparatedByString:@"."])
    {
        if (component.length == 0)
            return nil;
        [components addObject:@([component longLongValue])];
    }
    return components.count == 0 ? nil : components;
}

static NSComparisonResult TGLightGramUpdaterCompareVersions(NSArray *lhs, NSArray *rhs)
{
    NSUInteger count = MAX(lhs.count, rhs.count);
    for (NSUInteger index = 0; index < count; index++)
    {
        long long left = index < lhs.count ? [lhs[index] longLongValue] : 0;
        long long right = index < rhs.count ? [rhs[index] longLongValue] : 0;
        if (left != right)
            return left < right ? NSOrderedAscending : NSOrderedDescending;
    }
    return NSOrderedSame;
}

static bool TGLightGramUpdaterHostIsTrusted(NSString *host)
{
    NSString *lowercaseHost = [host lowercaseString];
    return [lowercaseHost isEqualToString:@"github.com"] || [lowercaseHost isEqualToString:@"api.github.com"] || [lowercaseHost hasSuffix:@".githubusercontent.com"];
}

static NSData *TGLightGramUpdaterDigestFromChecksumText(NSData *data)
{
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSCharacterSet *separators = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (NSString *token in [text componentsSeparatedByCharactersInSet:separators])
    {
        if (token.length != CC_SHA256_DIGEST_LENGTH * 2)
            continue;
        NSMutableData *digest = [[NSMutableData alloc] initWithLength:CC_SHA256_DIGEST_LENGTH];
        uint8_t *bytes = digest.mutableBytes;
        bool valid = true;
        for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH && valid; index++)
        {
            unsigned int value = 0;
            NSScanner *scanner = [NSScanner scannerWithString:[token substringWithRange:NSMakeRange(index * 2, 2)]];
            valid = [scanner scanHexInt:&value] && [scanner isAtEnd];
            bytes[index] = (uint8_t)value;
        }
        if (valid)
            return digest;
    }
    return nil;
}

static bool TGLightGramUpdaterHasInstallEntitlement(void)
{
    typedef void *(*TGLightGramUpdaterTaskCreate)(CFAllocatorRef allocator);
    typedef CFTypeRef (*TGLightGramUpdaterTaskCopyEntitlement)(void *task, CFStringRef entitlement, CFErrorRef *error);
    TGLightGramUpdaterTaskCreate createTask = (TGLightGramUpdaterTaskCreate)dlsym(RTLD_DEFAULT, "SecTaskCreateFromSelf");
    TGLightGramUpdaterTaskCopyEntitlement copyEntitlement = (TGLightGramUpdaterTaskCopyEntitlement)dlsym(RTLD_DEFAULT, "SecTaskCopyValueForEntitlement");
    if (createTask == NULL || copyEntitlement == NULL)
        return false;
    void *task = createTask(kCFAllocatorDefault);
    if (task == NULL)
        return false;
    CFTypeRef value = copyEntitlement(task, (__bridge CFStringRef)TGLightGramUpdaterInstallEntitlement, NULL);
    CFRelease(task);
    if (value == NULL)
        return false;
    bool allowed = CFGetTypeID(value) == CFArrayGetTypeID() && CFArrayContainsValue((CFArrayRef)value, CFRangeMake(0, CFArrayGetCount((CFArrayRef)value)), (__bridge CFStringRef)TGLightGramUpdaterInstallSPI);
    CFRelease(value);
    return allowed;
}

static id TGLightGramUpdaterApplicationWorkspace(void)
{
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    SEL defaultSelector = NSSelectorFromString(@"defaultWorkspace");
    if (workspaceClass == nil || ![workspaceClass respondsToSelector:defaultSelector] || ![workspaceClass instancesRespondToSelector:NSSelectorFromString(@"installApplication:withOptions:error:")])
        return nil;
    id (*defaultWorkspace)(id, SEL) = (id (*)(id, SEL))[workspaceClass methodForSelector:defaultSelector];
    return defaultWorkspace == NULL ? nil : defaultWorkspace(workspaceClass, defaultSelector);
}

static bool TGLightGramUpdaterInstallPackage(NSString *packagePath, NSString *bundleIdentifier, NSError **error)
{
    id workspace = TGLightGramUpdaterApplicationWorkspace();
    if (workspace == nil || bundleIdentifier.length == 0)
        return false;
    SEL selector = NSSelectorFromString(@"installApplication:withOptions:error:");
    BOOL (*install)(id, SEL, NSURL *, NSDictionary *, NSError **) = (BOOL (*)(id, SEL, NSURL *, NSDictionary *, NSError **))[workspace methodForSelector:selector];
    return install != NULL && install(workspace, selector, [NSURL fileURLWithPath:packagePath], @{@"CFBundleIdentifier": bundleIdentifier}, error);
}

@interface TGLightGramRelease ()

@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *notes;
@property (nonatomic, strong) NSURL *pageURL;
@property (nonatomic, strong) NSURL *packageURL;
@property (nonatomic, strong) NSURL *checksumURL;
@property (nonatomic) uint64_t packageSize;

@end

@implementation TGLightGramRelease

+ (NSString *)stringFromObject:(id)object
{
    return [object isKindOfClass:[NSString class]] ? object : nil;
}

+ (TGLightGramRelease *)releaseWithObject:(id)object
{
    if (![object isKindOfClass:[NSDictionary class]])
        return nil;
    NSDictionary *dictionary = object;
    if ([dictionary[@"draft"] respondsToSelector:@selector(boolValue)] && [dictionary[@"draft"] boolValue])
        return nil;
    if ([dictionary[@"prerelease"] respondsToSelector:@selector(boolValue)] && [dictionary[@"prerelease"] boolValue])
        return nil;

    NSString *tag = [self stringFromObject:dictionary[@"tag_name"]];
    NSArray *versionComponents = TGLightGramUpdaterVersionComponents(tag);
    if (versionComponents == nil)
        return nil;

    NSMutableDictionary *assetsByName = [[NSMutableDictionary alloc] init];
    NSArray *assets = [dictionary[@"assets"] isKindOfClass:[NSArray class]] ? dictionary[@"assets"] : nil;
    for (id asset in assets)
    {
        if (![asset isKindOfClass:[NSDictionary class]])
            continue;
        NSString *name = [self stringFromObject:asset[@"name"]];
        if (name.length != 0)
            assetsByName[name] = asset;
    }

    NSDictionary *package = nil;
    NSDictionary *checksum = nil;
    for (NSString *name in [[assetsByName allKeys] sortedArrayUsingSelector:@selector(compare:)])
    {
        if (![[[name pathExtension] lowercaseString] isEqualToString:@"ipa"])
            continue;
        NSDictionary *candidateChecksum = assetsByName[[name stringByAppendingString:@".sha256"]];
        if (candidateChecksum == nil)
            continue;
        bool universal = [name rangeOfString:TGLightGramUpdaterUniversalMarker].location != NSNotFound;
        if (package == nil || universal)
        {
            package = assetsByName[name];
            checksum = candidateChecksum;
            if (universal)
                break;
        }
    }
    if (package == nil)
        return nil;

    NSURL *packageURL = [NSURL URLWithString:[self stringFromObject:package[@"browser_download_url"]] ?: @""];
    NSURL *checksumURL = [NSURL URLWithString:[self stringFromObject:checksum[@"browser_download_url"]] ?: @""];
    if (packageURL == nil || checksumURL == nil || ![[packageURL scheme] isEqualToString:@"https"] || ![[checksumURL scheme] isEqualToString:@"https"])
        return nil;

    TGLightGramRelease *release = [[TGLightGramRelease alloc] init];
    release.version = [versionComponents componentsJoinedByString:@"."];
    release.title = [self stringFromObject:dictionary[@"name"]].length != 0 ? [self stringFromObject:dictionary[@"name"]] : tag;
    release.notes = [self stringFromObject:dictionary[@"body"]];
    release.pageURL = [NSURL URLWithString:[self stringFromObject:dictionary[@"html_url"]] ?: @""] ?: [TGLightGramUpdater releasesPageURL];
    release.packageURL = packageURL;
    release.checksumURL = checksumURL;
    release.packageSize = [package[@"size"] respondsToSelector:@selector(unsignedLongLongValue)] ? [package[@"size"] unsignedLongLongValue] : 0;
    return release;
}

@end

@interface TGLightGramUpdaterTransfer : NSObject
{
@public
    NSMutableData *_data;
    int _fd;
    bool _digesting;
    CC_SHA256_CTX _digest;
    uint64_t _received;
    volatile int *_cancelled;
    void (^_progress)(uint64_t received, int64_t expected);
}

@end

@implementation TGLightGramUpdaterTransfer

@end

static int TGLightGramUpdaterTransferIsCancelled(void *context)
{
    TGLightGramUpdaterTransfer *transfer = (__bridge TGLightGramUpdaterTransfer *)context;
    return transfer->_cancelled != NULL && *transfer->_cancelled != 0;
}

static int TGLightGramUpdaterTransferReceive(void *context, const uint8_t *bytes, size_t length, int64_t expectedLength)
{
    TGLightGramUpdaterTransfer *transfer = (__bridge TGLightGramUpdaterTransfer *)context;
    if (transfer->_data != nil)
        [transfer->_data appendBytes:bytes length:length];
    else
    {
        const uint8_t *cursor = bytes;
        size_t remaining = length;
        while (remaining > 0)
        {
            ssize_t written = write(transfer->_fd, cursor, remaining);
            if (written < 0 && errno == EINTR)
                continue;
            if (written <= 0)
                return 1;
            cursor += written;
            remaining -= (size_t)written;
        }
    }
    if (transfer->_digesting)
        CC_SHA256_Update(&transfer->_digest, bytes, (CC_LONG)length);
    transfer->_received += length;
    if (transfer->_progress != nil)
        transfer->_progress(transfer->_received, expectedLength);
    return 0;
}

@interface TGLightGramUpdater ()
{
    dispatch_queue_t _queue;
    volatile int _cancelled;
    volatile int _committing;
    LGPlatformBackgroundTaskIdentifier _backgroundTask;
}

@property (nonatomic) TGLightGramUpdaterState state;
@property (nonatomic) TGLightGramUpdaterError error;
@property (nonatomic, strong) TGLightGramRelease *latestRelease;
@property (nonatomic) float progress;
@property (nonatomic, strong) NSDate *lastCheckDate;

@end

@implementation TGLightGramUpdater

+ (TGLightGramUpdater *)sharedUpdater
{
    static TGLightGramUpdater *updater = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        updater = [[TGLightGramUpdater alloc] init];
    });
    return updater;
}

+ (NSString *)currentVersion
{
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return [version isKindOfClass:[NSString class]] ? version : @"";
}

+ (NSURL *)releasesPageURL
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://github.com/%@/releases/latest", TGLightGramUpdaterRepository]];
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _queue = dispatch_queue_create("org.onegram.updater", NULL);
        _backgroundTask = LGPlatformBackgroundTaskInvalid;
        id lastCheck = [[NSUserDefaults standardUserDefaults] objectForKey:TGLightGramUpdaterLastCheckKey];
        _lastCheckDate = [lastCheck isKindOfClass:[NSDate class]] ? lastCheck : nil;
        unlink([[NSTemporaryDirectory() stringByAppendingPathComponent:TGLightGramUpdaterPackageName] fileSystemRepresentation]);
    }
    return self;
}

- (void)setState:(TGLightGramUpdaterState)state error:(TGLightGramUpdaterError)error
{
    _state = state;
    _error = error;
    [[NSNotificationCenter defaultCenter] postNotificationName:TGLightGramUpdaterStateChangedNotification object:self];
}

- (void)publishProgress:(float)progress
{
    TGDispatchOnMainThread(^
    {
        if (_state != TGLightGramUpdaterStateDownloading && _state != TGLightGramUpdaterStateInstalling)
            return;
        if (fabsf(progress - _progress) < 0.005f && progress < 1.0f)
            return;
        _progress = progress;
        [[NSNotificationCenter defaultCenter] postNotificationName:TGLightGramUpdaterStateChangedNotification object:self];
    });
}

- (bool)hasNewerRelease
{
    return _latestRelease != nil && TGLightGramUpdaterCompareVersions(TGLightGramUpdaterVersionComponents(_latestRelease.version), TGLightGramUpdaterVersionComponents([TGLightGramUpdater currentVersion])) == NSOrderedDescending;
}

- (bool)canInstallInPlace
{
    return access([[[NSBundle mainBundle] bundlePath] fileSystemRepresentation], W_OK | X_OK) == 0;
}

- (bool)systemInstallerAvailable
{
    static bool available = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        available = TGLightGramUpdaterHasInstallEntitlement() && TGLightGramUpdaterApplicationWorkspace() != nil;
    });
    return available;
}

- (bool)usesSystemInstaller
{
    return ![self canInstallInPlace] && [self systemInstallerAvailable];
}

- (bool)canInstall
{
    return [self canInstallInPlace] || [self systemInstallerAvailable];
}

- (bool)canCancel
{
    return (_state == TGLightGramUpdaterStateDownloading || _state == TGLightGramUpdaterStateInstalling) && _committing == 0;
}

- (void)cancel
{
    if ([self canCancel])
        _cancelled = 1;
}

- (bool)isBusy
{
    return _state == TGLightGramUpdaterStateChecking || _state == TGLightGramUpdaterStateDownloading || _state == TGLightGramUpdaterStateInstalling || _state == TGLightGramUpdaterStateInstalled;
}

#pragma mark - Transport

- (TGLightGramUpdaterError)fetchURL:(NSURL *)url accept:(NSString *)accept limit:(uint64_t)limit transfer:(TGLightGramUpdaterTransfer *)transfer
{
    NSString *userAgent = [NSString stringWithFormat:@"User-Agent: LightGram/%@", [TGLightGramUpdater currentVersion]];
    NSString *acceptHeader = [@"Accept: " stringByAppendingString:accept];
    NSURL *current = url;

    for (int hop = 0; hop <= TGLightGramUpdaterRedirectLimit; hop++)
    {
        if (![[[current scheme] lowercaseString] isEqualToString:@"https"] || !TGLightGramUpdaterHostIsTrusted([current host]) || ([current port] != nil && [[current port] intValue] != 443))
            return TGLightGramUpdaterErrorNetwork;

        NSString *path = (__bridge_transfer NSString *)CFURLCopyPath((__bridge CFURLRef)current);
        NSString *query = (__bridge_transfer NSString *)CFURLCopyQueryString((__bridge CFURLRef)current, NULL);
        NSString *resource = path.length == 0 ? @"/" : path;
        if (query.length != 0)
            resource = [resource stringByAppendingFormat:@"?%@", query];

        const char *headers[] = {[userAgent UTF8String], [acceptHeader UTF8String], NULL};
        LGCoreFetchRequest request;
        memset(&request, 0, sizeof(request));
        request.host = [[current host] UTF8String];
        request.port = 443;
        request.path = [resource UTF8String];
        request.headers = headers;
        request.idleTimeoutSeconds = TGLightGramUpdaterIdleTimeoutSeconds;
        request.maximumBodyLength = limit;
        request.isCancelled = TGLightGramUpdaterTransferIsCancelled;
        request.receiveBody = TGLightGramUpdaterTransferReceive;
        request.context = (__bridge void *)transfer;

        LGCoreFetchHead head;
        LGCoreFetchStatus status = LGCoreHTTPSFetch(&request, &head);
        if (status != LGCoreFetchStatusOK)
        {
            TGLog(@"UPDATE fetch.failed host=%@ status=%d", [current host], (int)status);
            if (status == LGCoreFetchStatusCertificate)
                return TGLightGramUpdaterErrorCertificate;
            if (status == LGCoreFetchStatusTooLarge)
                return TGLightGramUpdaterErrorRelease;
            if (status == LGCoreFetchStatusRejected)
                return TGLightGramUpdaterErrorStorage;
            return TGLightGramUpdaterErrorNetwork;
        }

        if (head.statusCode == 200)
            return TGLightGramUpdaterErrorNone;

        if ((head.statusCode == 301 || head.statusCode == 302 || head.statusCode == 303 || head.statusCode == 307 || head.statusCode == 308) && head.location[0] != 0)
        {
            NSString *location = [[NSString alloc] initWithUTF8String:head.location];
            current = location == nil ? nil : [[NSURL URLWithString:location relativeToURL:current] absoluteURL];
            if (current == nil)
                return TGLightGramUpdaterErrorNetwork;
            continue;
        }

        TGLog(@"UPDATE fetch.status host=%@ code=%d", [url host], head.statusCode);
        return head.statusCode == 404 ? TGLightGramUpdaterErrorRelease : TGLightGramUpdaterErrorNetwork;
    }
    return TGLightGramUpdaterErrorNetwork;
}

#pragma mark - Checking

- (void)checkForUpdatesIfNeeded
{
    if (_lastCheckDate != nil && -[_lastCheckDate timeIntervalSinceNow] < TGLightGramUpdaterCheckInterval)
        return;
    [self checkForUpdates];
}

- (void)checkForUpdates
{
    TGDispatchOnMainThread(^
    {
        if ([self isBusy])
            return;
        [self setState:TGLightGramUpdaterStateChecking error:TGLightGramUpdaterErrorNone];

        dispatch_async(_queue, ^
        {
            TGLightGramUpdaterTransfer *transfer = [[TGLightGramUpdaterTransfer alloc] init];
            transfer->_data = [[NSMutableData alloc] init];
            transfer->_fd = -1;

            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.github.com/repos/%@/releases/latest", TGLightGramUpdaterRepository]];
            TGLightGramUpdaterError error = [self fetchURL:url accept:@"application/vnd.github+json" limit:TGLightGramUpdaterMetadataLimit transfer:transfer];
            TGLightGramRelease *release = nil;
            bool noRelease = error == TGLightGramUpdaterErrorRelease;
            if (error == TGLightGramUpdaterErrorNone)
            {
                release = [TGLightGramRelease releaseWithObject:LGCoreJSONObjectWithData(transfer->_data, NULL)];
                if (release == nil)
                    noRelease = true;
            }

            TGDispatchOnMainThread(^
            {
                NSDate *now = [NSDate date];
                if (error == TGLightGramUpdaterErrorNone || noRelease)
                {
                    _lastCheckDate = now;
                    [[NSUserDefaults standardUserDefaults] setObject:now forKey:TGLightGramUpdaterLastCheckKey];
                }

                _latestRelease = release;
                if ([self hasNewerRelease])
                    [self setState:TGLightGramUpdaterStateAvailable error:TGLightGramUpdaterErrorNone];
                else if (error == TGLightGramUpdaterErrorNone || noRelease)
                    [self setState:TGLightGramUpdaterStateUpToDate error:TGLightGramUpdaterErrorNone];
                else
                    [self setState:TGLightGramUpdaterStateFailed error:error];
                TGLog(@"UPDATE check current=%@ latest=%@ state=%d error=%d", [TGLightGramUpdater currentVersion], release.version, (int)_state, (int)error);
            });
        });
    });
}

#pragma mark - Installation

- (void)installLatestRelease
{
    TGDispatchOnMainThread(^
    {
        TGLightGramRelease *release = _latestRelease;
        if ((_state != TGLightGramUpdaterStateAvailable && _state != TGLightGramUpdaterStateFailed) || ![self hasNewerRelease])
            return;

        _cancelled = 0;
        _committing = 0;
        _progress = 0.0f;
        [UIApplication sharedApplication].idleTimerDisabled = true;
        __weak TGLightGramUpdater *weakSelf = self;
        _backgroundTask = LGPlatformBeginBackgroundTask([UIApplication sharedApplication], ^
        {
            __strong TGLightGramUpdater *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            if (strongSelf->_committing == 0)
                strongSelf->_cancelled = 1;
            LGPlatformBackgroundTaskIdentifier task = strongSelf->_backgroundTask;
            strongSelf->_backgroundTask = LGPlatformBackgroundTaskInvalid;
            LGPlatformEndBackgroundTask([UIApplication sharedApplication], task);
        });
        [self setState:TGLightGramUpdaterStateDownloading error:TGLightGramUpdaterErrorNone];

        dispatch_async(_queue, ^
        {
            TGLightGramUpdaterError error = [self performInstallationOfRelease:release];
            bool cancelled = _cancelled != 0 && error != TGLightGramUpdaterErrorNone;

            TGDispatchOnMainThread(^
            {
                [UIApplication sharedApplication].idleTimerDisabled = false;
                if (_backgroundTask != LGPlatformBackgroundTaskInvalid)
                {
                    LGPlatformEndBackgroundTask([UIApplication sharedApplication], _backgroundTask);
                    _backgroundTask = LGPlatformBackgroundTaskInvalid;
                }
                _committing = 0;
                if (error == TGLightGramUpdaterErrorNone)
                {
                    _progress = 1.0f;
                    [self setState:TGLightGramUpdaterStateInstalled error:TGLightGramUpdaterErrorNone];
                }
                else if (cancelled)
                    [self setState:TGLightGramUpdaterStateAvailable error:TGLightGramUpdaterErrorNone];
                else
                    [self setState:TGLightGramUpdaterStateFailed error:error];
                TGLog(@"UPDATE install version=%@ error=%d cancelled=%d", release.version, (int)error, (int)cancelled);
            });
        });
    });
}

- (TGLightGramUpdaterError)errorForArchiveStatus:(LGUpdateArchiveStatus)status
{
    switch (status)
    {
        case LGUpdateArchiveStatusOK:
            return TGLightGramUpdaterErrorNone;
        case LGUpdateArchiveStatusNoSpace:
            return TGLightGramUpdaterErrorStorage;
        case LGUpdateArchiveStatusNotWritable:
            return TGLightGramUpdaterErrorNotWritable;
        case LGUpdateArchiveStatusIO:
            return TGLightGramUpdaterErrorInstall;
        default:
            return TGLightGramUpdaterErrorArchive;
    }
}

- (bool)hasFreeSpace:(uint64_t)required atPath:(NSString *)path
{
    struct statfs volume;
    if (statfs([path fileSystemRepresentation], &volume) != 0)
        return true;
    return (uint64_t)volume.f_bavail * (uint64_t)volume.f_bsize >= required + TGLightGramUpdaterSpaceReserve;
}

- (TGLightGramUpdaterError)downloadRelease:(TGLightGramRelease *)release toPath:(NSString *)packagePath
{
    TGLightGramUpdaterTransfer *checksumTransfer = [[TGLightGramUpdaterTransfer alloc] init];
    checksumTransfer->_data = [[NSMutableData alloc] init];
    checksumTransfer->_fd = -1;
    checksumTransfer->_cancelled = &_cancelled;
    TGLightGramUpdaterError error = [self fetchURL:release.checksumURL accept:@"application/octet-stream" limit:TGLightGramUpdaterChecksumLimit transfer:checksumTransfer];
    if (error != TGLightGramUpdaterErrorNone)
        return error;

    NSData *expectedDigest = TGLightGramUpdaterDigestFromChecksumText(checksumTransfer->_data);
    if (expectedDigest == nil)
        return TGLightGramUpdaterErrorRelease;
    if (release.packageSize > TGLightGramUpdaterPackageLimit)
        return TGLightGramUpdaterErrorRelease;
    if (![self hasFreeSpace:release.packageSize atPath:[packagePath stringByDeletingLastPathComponent]])
        return TGLightGramUpdaterErrorStorage;

    unlink([packagePath fileSystemRepresentation]);
    int fd = open([packagePath fileSystemRepresentation], O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (fd < 0)
        return TGLightGramUpdaterErrorStorage;

    TGLightGramUpdaterTransfer *packageTransfer = [[TGLightGramUpdaterTransfer alloc] init];
    packageTransfer->_fd = fd;
    packageTransfer->_digesting = true;
    CC_SHA256_Init(&packageTransfer->_digest);
    packageTransfer->_cancelled = &_cancelled;
    uint64_t announcedSize = release.packageSize;
    __weak TGLightGramUpdater *weakSelf = self;
    packageTransfer->_progress = ^(uint64_t received, int64_t expected)
    {
        uint64_t total = announcedSize != 0 ? announcedSize : (expected > 0 ? (uint64_t)expected : 0);
        if (total != 0)
            [weakSelf publishProgress:TGLightGramUpdaterDownloadShare * (float)MIN(1.0, (double)received / (double)total)];
    };

    error = [self fetchURL:release.packageURL accept:@"application/octet-stream" limit:TGLightGramUpdaterPackageLimit transfer:packageTransfer];
    if (close(fd) != 0 && error == TGLightGramUpdaterErrorNone)
        error = TGLightGramUpdaterErrorStorage;
    if (error != TGLightGramUpdaterErrorNone)
        return error;

    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &packageTransfer->_digest);
    if (memcmp(digest, expectedDigest.bytes, CC_SHA256_DIGEST_LENGTH) != 0)
        return TGLightGramUpdaterErrorChecksum;
    return TGLightGramUpdaterErrorNone;
}

- (NSString *)validatedExecutableInStagedBundle:(NSString *)stagingPath release:(TGLightGramRelease *)release
{
    NSDictionary *stagedInfo = [NSDictionary dictionaryWithContentsOfFile:[stagingPath stringByAppendingPathComponent:@"Info.plist"]];
    NSString *bundleIdentifier = stagedInfo[@"CFBundleIdentifier"];
    NSString *executable = stagedInfo[@"CFBundleExecutable"];
    NSString *version = stagedInfo[@"CFBundleShortVersionString"];

    if (![bundleIdentifier isKindOfClass:[NSString class]] || ![bundleIdentifier isEqualToString:[[NSBundle mainBundle] bundleIdentifier]])
        return nil;
    if (![executable isKindOfClass:[NSString class]] || executable.length == 0 || [executable rangeOfString:@"/"].location != NSNotFound)
        return nil;
    if (![version isKindOfClass:[NSString class]] || TGLightGramUpdaterCompareVersions(TGLightGramUpdaterVersionComponents(version), TGLightGramUpdaterVersionComponents(release.version)) != NSOrderedSame)
        return nil;
    const char *executablePath = [[stagingPath stringByAppendingPathComponent:executable] fileSystemRepresentation];
    struct stat executableInfo;
    if (lstat(executablePath, &executableInfo) != 0 || !S_ISREG(executableInfo.st_mode))
        return nil;
    if ((executableInfo.st_mode & 0111) != 0111 && chmod(executablePath, 0755) != 0)
        return nil;
    return executable;
}

- (TGLightGramUpdaterError)performInstallationOfRelease:(TGLightGramRelease *)release
{
    if ([self canInstallInPlace])
        return [self performInPlaceInstallationOfRelease:release];
    if ([self systemInstallerAvailable])
        return [self performSystemInstallationOfRelease:release];
    return TGLightGramUpdaterErrorNotWritable;
}

- (TGLightGramUpdaterError)performSystemInstallationOfRelease:(TGLightGramRelease *)release
{
    NSString *packagePath = [NSTemporaryDirectory() stringByAppendingPathComponent:TGLightGramUpdaterPackageName];
    TGLightGramUpdaterError error = [self downloadRelease:release toPath:packagePath];
    if (error == TGLightGramUpdaterErrorNone && _cancelled != 0)
        error = TGLightGramUpdaterErrorInstall;
    if (error == TGLightGramUpdaterErrorNone && chmod([packagePath fileSystemRepresentation], 0644) != 0)
        error = TGLightGramUpdaterErrorStorage;
    if (error != TGLightGramUpdaterErrorNone)
    {
        unlink([packagePath fileSystemRepresentation]);
        return error;
    }

    _committing = 1;
    TGDispatchOnMainThread(^
    {
        if (_state == TGLightGramUpdaterStateDownloading)
            [self setState:TGLightGramUpdaterStateInstalling error:TGLightGramUpdaterErrorNone];
    });

    NSError *installError = nil;
    bool installed = TGLightGramUpdaterInstallPackage(packagePath, [[NSBundle mainBundle] bundleIdentifier], &installError);
    unlink([packagePath fileSystemRepresentation]);
    if (!installed)
    {
        TGLog(@"UPDATE system.install.failed error=%@", installError);
        return TGLightGramUpdaterErrorInstall;
    }
    return TGLightGramUpdaterErrorNone;
}

- (TGLightGramUpdaterError)performInPlaceInstallationOfRelease:(TGLightGramRelease *)release
{
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *packagePath = [NSTemporaryDirectory() stringByAppendingPathComponent:TGLightGramUpdaterPackageName];
    NSString *stagingPath = [bundlePath stringByAppendingPathComponent:TGLightGramUpdaterStagingName];

    TGLightGramUpdaterError error = [self downloadRelease:release toPath:packagePath];
    if (error != TGLightGramUpdaterErrorNone)
    {
        unlink([packagePath fileSystemRepresentation]);
        return error;
    }

    TGDispatchOnMainThread(^
    {
        if (_state == TGLightGramUpdaterStateDownloading)
            [self setState:TGLightGramUpdaterStateInstalling error:TGLightGramUpdaterErrorNone];
    });

    LGUpdateArchiveStatus status = [LGUpdateArchive prepareDirectoryAtPath:stagingPath];
    if (status == LGUpdateArchiveStatusOK)
    {
        volatile int *cancelled = &_cancelled;
        __weak TGLightGramUpdater *weakSelf = self;
        status = [LGUpdateArchive extractApplicationFromArchiveAtPath:packagePath toDirectory:stagingPath isCancelled:^bool
        {
            return *cancelled != 0;
        } progress:^(uint64_t completed, uint64_t total)
        {
            if (total != 0)
                [weakSelf publishProgress:TGLightGramUpdaterDownloadShare + TGLightGramUpdaterExtractShare * (float)((double)completed / (double)total)];
        }];
    }
    unlink([packagePath fileSystemRepresentation]);

    NSString *executable = nil;
    if (status == LGUpdateArchiveStatusOK)
    {
        executable = [self validatedExecutableInStagedBundle:stagingPath release:release];
        if (executable == nil)
        {
            [LGUpdateArchive removeItemAtPath:stagingPath];
            return TGLightGramUpdaterErrorPackage;
        }
    }
    if (status == LGUpdateArchiveStatusOK && _cancelled != 0)
        status = LGUpdateArchiveStatusCancelled;
    if (status != LGUpdateArchiveStatusOK)
    {
        [LGUpdateArchive removeItemAtPath:stagingPath];
        return [self errorForArchiveStatus:status];
    }

    _committing = 1;
    __weak TGLightGramUpdater *weakSelf = self;
    float committedShare = TGLightGramUpdaterDownloadShare + TGLightGramUpdaterExtractShare;
    status = [LGUpdateArchive replaceBundleAtPath:bundlePath withStagedBundleAtPath:stagingPath executableName:executable progress:^(uint64_t completed, uint64_t total)
    {
        if (total != 0)
            [weakSelf publishProgress:committedShare + (1.0f - committedShare) * (float)((double)completed / (double)total)];
    }];
    if (status != LGUpdateArchiveStatusOK)
    {
        TGLog(@"UPDATE commit.failed status=%d", (int)status);
        return TGLightGramUpdaterErrorInstall;
    }

    [self refreshHomeScreen];
    return TGLightGramUpdaterErrorNone;
}

- (void)refreshHomeScreen
{
    static const char *path = "/usr/bin/uicache";
    if (access(path, X_OK) != 0)
        return;

    char *const arguments[] = {(char *)"uicache", NULL};
    pid_t process = 0;
    if (posix_spawn(&process, path, NULL, NULL, arguments, environ) != 0)
        return;

    int status = 0;
    while (waitpid(process, &status, 0) < 0 && errno == EINTR)
    {
    }
}

@end
