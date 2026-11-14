#import <Foundation/Foundation.h>

typedef enum {
    TGLightGramUpdaterStateIdle = 0,
    TGLightGramUpdaterStateChecking,
    TGLightGramUpdaterStateUpToDate,
    TGLightGramUpdaterStateAvailable,
    TGLightGramUpdaterStateDownloading,
    TGLightGramUpdaterStateInstalling,
    TGLightGramUpdaterStateInstalled,
    TGLightGramUpdaterStateFailed
} TGLightGramUpdaterState;

typedef enum {
    TGLightGramUpdaterErrorNone = 0,
    TGLightGramUpdaterErrorNetwork,
    TGLightGramUpdaterErrorCertificate,
    TGLightGramUpdaterErrorRelease,
    TGLightGramUpdaterErrorChecksum,
    TGLightGramUpdaterErrorArchive,
    TGLightGramUpdaterErrorPackage,
    TGLightGramUpdaterErrorStorage,
    TGLightGramUpdaterErrorNotWritable,
    TGLightGramUpdaterErrorInstall
} TGLightGramUpdaterError;

extern NSString *const TGLightGramUpdaterStateChangedNotification;

@interface TGLightGramRelease : NSObject

@property (nonatomic, strong, readonly) NSString *version;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *notes;
@property (nonatomic, strong, readonly) NSURL *pageURL;
@property (nonatomic, strong, readonly) NSURL *packageURL;
@property (nonatomic, strong, readonly) NSURL *checksumURL;
@property (nonatomic, readonly) uint64_t packageSize;

@end

@interface TGLightGramUpdater : NSObject

@property (nonatomic, readonly) TGLightGramUpdaterState state;
@property (nonatomic, readonly) TGLightGramUpdaterError error;
@property (nonatomic, strong, readonly) TGLightGramRelease *latestRelease;
@property (nonatomic, readonly) float progress;
@property (nonatomic, strong, readonly) NSDate *lastCheckDate;

+ (TGLightGramUpdater *)sharedUpdater;
+ (NSString *)currentVersion;
+ (NSURL *)releasesPageURL;

- (bool)hasNewerRelease;
- (bool)canInstall;
- (bool)usesSystemInstaller;
- (bool)canCancel;
- (void)checkForUpdates;
- (void)checkForUpdatesIfNeeded;
- (void)installLatestRelease;
- (void)cancel;

@end
