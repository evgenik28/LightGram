#import "TGLightGramUpdateController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGAppDelegate.h"
#import "TGRootController.h"
#import "TGCustomAlertView.h"
#import "TGLightGramUpdater.h"

static NSString *const TGLightGramUpdateDismissedVersionKey = @"TGLightGramUpdateDismissedVersion";
static const NSUInteger TGLightGramUpdateNotesLimit = 1500;
static bool TGLightGramUpdateLaunchPromptArmed = false;
static NSString *TGLightGramUpdatePromptedVersion = nil;

static NSString *TGLightGramUpdateErrorText(TGLightGramUpdaterError error)
{
    switch (error)
    {
        case TGLightGramUpdaterErrorNone:
            return nil;
        case TGLightGramUpdaterErrorNetwork:
            return TGLocalized(@"LightGramUpdate.Error.Network");
        case TGLightGramUpdaterErrorCertificate:
            return TGLocalized(@"LightGramUpdate.Error.Certificate");
        case TGLightGramUpdaterErrorRelease:
            return TGLocalized(@"LightGramUpdate.Error.Release");
        case TGLightGramUpdaterErrorChecksum:
            return TGLocalized(@"LightGramUpdate.Error.Checksum");
        case TGLightGramUpdaterErrorArchive:
            return TGLocalized(@"LightGramUpdate.Error.Archive");
        case TGLightGramUpdaterErrorPackage:
            return TGLocalized(@"LightGramUpdate.Error.Package");
        case TGLightGramUpdaterErrorStorage:
            return TGLocalized(@"LightGramUpdate.Error.Storage");
        case TGLightGramUpdaterErrorNotWritable:
            return TGLocalized(@"LightGramUpdate.InPlaceUnavailable");
        case TGLightGramUpdaterErrorInstall:
            return TGLocalized(@"LightGramUpdate.Error.Install");
    }
    return nil;
}

@interface TGLightGramUpdateController ()
{
    TGLightGramUpdaterState _builtState;
    TGLightGramActionCollectionItem *_progressItem;
    bool _updaterRebuildScheduled;
}

@end

@implementation TGLightGramUpdateController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (NSString *)statusVariant
{
    TGLightGramUpdater *updater = [TGLightGramUpdater sharedUpdater];
    if ([updater hasNewerRelease])
        return updater.latestRelease.version;
    return [TGLightGramUpdater currentVersion];
}

+ (void)startAutomaticCheck
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(launchUpdaterStateChanged:) name:TGLightGramUpdaterStateChangedNotification object:nil];
        [center addObserver:self selector:@selector(launchUpdaterStateChanged:) name:UIApplicationDidBecomeActiveNotification object:nil];
    });
    TGLightGramUpdateLaunchPromptArmed = true;
    TGLightGramUpdater *updater = [TGLightGramUpdater sharedUpdater];
    if (updater.state == TGLightGramUpdaterStateIdle)
        [updater checkForUpdates];
    else if (updater.state == TGLightGramUpdaterStateAvailable)
        [self launchUpdaterStateChanged:nil];
    else
        [updater checkForUpdatesIfNeeded];
}

+ (void)launchUpdaterStateChanged:(NSNotification *)__unused notification
{
    TGLightGramUpdater *updater = [TGLightGramUpdater sharedUpdater];
    if (!TGLightGramUpdateLaunchPromptArmed || updater.state == TGLightGramUpdaterStateChecking)
        return;
    bool available = updater.state == TGLightGramUpdaterStateAvailable && [updater hasNewerRelease];
    if (available && [UIApplication sharedApplication].applicationState != UIApplicationStateActive)
        return;
    TGLightGramUpdateLaunchPromptArmed = false;

    if (!available)
        return;
    NSString *version = updater.latestRelease.version;
    if ([TGLightGramUpdatePromptedVersion isEqualToString:version] || [[[NSUserDefaults standardUserDefaults] objectForKey:TGLightGramUpdateDismissedVersionKey] isEqual:version])
        return;
    TGLightGramUpdatePromptedVersion = version;

    [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"LightGramUpdate.AlertTitle") message:[NSString stringWithFormat:TGLocalized(@"LightGramUpdate.AlertText"), version] cancelButtonTitle:TGLocalized(@"LightGramUpdate.Later") okButtonTitle:TGLocalized(@"LightGramUpdate.Update") completionBlock:^(bool okButtonPressed)
    {
        if (!okButtonPressed)
        {
            [[NSUserDefaults standardUserDefaults] setObject:version forKey:TGLightGramUpdateDismissedVersionKey];
            return;
        }
        [TGAppDelegateInstance.rootController pushContentController:[[TGLightGramUpdateController alloc] init]];
        TGLightGramUpdater *currentUpdater = [TGLightGramUpdater sharedUpdater];
        if ([currentUpdater canInstall])
            [currentUpdater installLatestRelease];
    }];
}

- (instancetype)init
{
    self = [super initWithTitle:TGLocalized(@"LightGramUpdate.Title")];
    if (self != nil)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updaterStateChanged:) name:TGLightGramUpdaterStateChangedNotification object:nil];
    return self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    TGLightGramUpdater *updater = [TGLightGramUpdater sharedUpdater];
    if (updater.state == TGLightGramUpdaterStateIdle)
        [updater checkForUpdates];
}

- (void)updaterStateChanged:(NSNotification *)__unused notification
{
    TGLightGramUpdater *updater = [TGLightGramUpdater sharedUpdater];
    if (updater.state == _builtState && _progressItem != nil)
    {
        _progressItem.variant = [self progressText];
        return;
    }
    if (_updaterRebuildScheduled)
        return;
    _updaterRebuildScheduled = true;
    __weak TGLightGramUpdateController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^
    {
        __strong TGLightGramUpdateController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_updaterRebuildScheduled = false;
        [strongSelf rebuild];
    });
}

- (NSString *)progressText
{
    return [NSString stringWithFormat:@"%d%%", (int)([TGLightGramUpdater sharedUpdater].progress * 100.0f)];
}

- (TGLightGramActionCollectionItem *)infoItemWithTitle:(NSString *)title variant:(NSString *)variant
{
    TGLightGramActionCollectionItem *item = [self actionWithTitle:title variant:variant pressed:nil];
    item.hideArrow = true;
    item.selectable = false;
    return item;
}

- (NSString *)versionFooter
{
    TGLightGramUpdater *updater = [TGLightGramUpdater sharedUpdater];
    switch (updater.state)
    {
        case TGLightGramUpdaterStateFailed:
            return TGLightGramUpdateErrorText(updater.error);
        case TGLightGramUpdaterStateUpToDate:
            return TGLocalized(@"LightGramUpdate.UpToDate");
        case TGLightGramUpdaterStateDownloading:
        case TGLightGramUpdaterStateInstalling:
            return TGLocalized(@"LightGramUpdate.InstallingInfo");
        case TGLightGramUpdaterStateInstalled:
            return TGLocalized(@"LightGramUpdate.RestartInfo");
        case TGLightGramUpdaterStateAvailable:
            if (![updater canInstall])
                return TGLocalized(@"LightGramUpdate.InPlaceUnavailable");
            if ([updater usesSystemInstaller])
                return TGLocalized(@"LightGramUpdate.SystemInstallInfo");
            break;
        default:
            break;
    }
    if (updater.lastCheckDate == nil)
        return nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [NSString stringWithFormat:TGLocalized(@"LightGramUpdate.LastCheck"), [formatter stringFromDate:updater.lastCheckDate]];
}

- (NSArray *)buildSections
{
    TGLightGramUpdater *updater = [TGLightGramUpdater sharedUpdater];
    TGLightGramRelease *release = updater.latestRelease;
    TGLightGramUpdaterState state = updater.state;
    __weak TGLightGramUpdateController *weakSelf = self;

    _builtState = state;
    _progressItem = nil;

    NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *installed = [build isKindOfClass:[NSString class]] && build.length != 0 ? [NSString stringWithFormat:@"%@ (%@)", [TGLightGramUpdater currentVersion], build] : [TGLightGramUpdater currentVersion];
    NSString *latest = release.version;
    if (latest == nil)
        latest = state == TGLightGramUpdaterStateChecking ? TGLocalized(@"LightGramUpdate.Checking") : @"—";

    NSMutableArray *sections = [[NSMutableArray alloc] init];
    [sections addObject:[self sectionWithHeader:nil items:@[
        [self infoItemWithTitle:TGLocalized(@"LightGramUpdate.Installed") variant:installed],
        [self infoItemWithTitle:TGLocalized(@"LightGramUpdate.Latest") variant:latest]
    ] footer:[self versionFooter]]];

    NSMutableArray *actions = [[NSMutableArray alloc] init];
    if (state == TGLightGramUpdaterStateDownloading || state == TGLightGramUpdaterStateInstalling)
    {
        _progressItem = [self infoItemWithTitle:TGLocalized(state == TGLightGramUpdaterStateDownloading ? @"LightGramUpdate.Downloading" : @"LightGramUpdate.Installing") variant:[self progressText]];
        [actions addObject:_progressItem];
        if ([updater canCancel])
        {
            [actions addObject:[self actionWithTitle:TGLocalized(@"LightGramUpdate.Cancel") variant:nil pressed:^
            {
                [[TGLightGramUpdater sharedUpdater] cancel];
            }]];
        }
    }
    else if (state == TGLightGramUpdaterStateInstalled)
    {
        [actions addObject:[self actionWithTitle:TGLocalized(@"LightGramUpdate.Restart") variant:nil pressed:^
        {
            [weakSelf restartPressed];
        }]];
    }
    else
    {
        if ([updater hasNewerRelease])
        {
            if ([updater canInstall])
            {
                [actions addObject:[self actionWithTitle:[NSString stringWithFormat:TGLocalized(@"LightGramUpdate.Install"), release.version] variant:nil pressed:^
                {
                    [[TGLightGramUpdater sharedUpdater] installLatestRelease];
                }]];
            }
            if (![updater canInstall] || (state == TGLightGramUpdaterStateFailed && updater.error == TGLightGramUpdaterErrorInstall))
            {
                NSURL *pageURL = release.pageURL;
                [actions addObject:[self actionWithTitle:TGLocalized(@"LightGramUpdate.OpenRelease") variant:nil pressed:^
                {
                    [[UIApplication sharedApplication] openURL:pageURL];
                }]];
            }
        }

        TGLightGramActionCollectionItem *checkItem = [self actionWithTitle:TGLocalized(@"LightGramUpdate.Check") variant:state == TGLightGramUpdaterStateChecking ? TGLocalized(@"LightGramUpdate.Checking") : nil pressed:^
        {
            [[TGLightGramUpdater sharedUpdater] checkForUpdates];
        }];
        checkItem.enabled = state != TGLightGramUpdaterStateChecking;
        [actions addObject:checkItem];
    }
    [sections addObject:[self sectionWithHeader:nil items:actions footer:nil]];

    if ([updater hasNewerRelease] && release.notes.length != 0)
    {
        NSString *notes = [release.notes stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (notes.length > TGLightGramUpdateNotesLimit)
            notes = [[notes substringToIndex:TGLightGramUpdateNotesLimit] stringByAppendingString:@"…"];
        [sections addObject:[self sectionWithHeader:release.title items:@[] footer:notes]];
    }

    return sections;
}

- (void)restartPressed
{
    [[NSUserDefaults standardUserDefaults] synchronize];
    exit(0);
}

@end
