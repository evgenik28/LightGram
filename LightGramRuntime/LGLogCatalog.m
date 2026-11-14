#import "LGLogCatalog.h"

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#import "../LightGramLauncher/LGSystemApplication.h"

#define LGHelperApplicationBundleIdentifier "dev.notdevv.LightGram"
#define LGHelperLogDirectoryPath "/var/mobile/Library/Logs"
#define LGHelperLogPath LGHelperLogDirectoryPath "/lightgramd.log"
#define LGHelperRotatedLogPath LGHelperLogDirectoryPath "/lightgramd.log.1"
#define LGHelperStandardErrorLogPath LGHelperLogDirectoryPath "/lightgramd.stderr.log"
#define LGHelperCrashReporterPath LGHelperLogDirectoryPath "/CrashReporter"

static const unsigned long long LGLogCatalogSystemReportInspectionLimit = 4 * 1024 * 1024;
static const NSUInteger LGLogCatalogFullTextLimit = 32 * 1024 * 1024;

@implementation LGLogEntry

- (instancetype)initWithPath:(NSString *)path name:(NSString *)name source:(LGLogSource)source modificationDate:(NSDate *)modificationDate size:(unsigned long long)size
{
    self = [super init];
    if (self != nil)
    {
        _path = [path copy];
        _name = [name copy];
        _source = source;
        _modificationDate = modificationDate;
        _size = size;
    }
    return self;
}

- (NSComparisonResult)compareNewestFirst:(LGLogEntry *)other
{
    if (_modificationDate == nil || other.modificationDate == nil)
    {
        if (_modificationDate != other.modificationDate)
            return _modificationDate == nil ? NSOrderedDescending : NSOrderedAscending;
        return [other.path compare:_path];
    }
    NSComparisonResult result = [other.modificationDate compare:_modificationDate];
    return result == NSOrderedSame ? [_path compare:other.path] : result;
}

@end

static LGLogEntry *LGLogCatalogEntry(NSString *path, NSString *name, LGLogSource source)
{
    struct stat info;
    if (stat(path.fileSystemRepresentation, &info) != 0 || !S_ISREG(info.st_mode) || info.st_size <= 0)
        return nil;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)info.st_mtime];
    return [[LGLogEntry alloc] initWithPath:path name:name source:source modificationDate:date size:(unsigned long long)info.st_size];
}

static void LGLogCatalogAddEntry(NSMutableArray *entries, NSMutableSet *knownPaths, NSString *path, NSString *name, LGLogSource source)
{
    NSString *standardized = [path stringByStandardizingPath];
    if ([knownPaths containsObject:standardized])
        return;
    LGLogEntry *entry = LGLogCatalogEntry(standardized, name, source);
    if (entry == nil)
        return;
    [knownPaths addObject:standardized];
    [entries addObject:entry];
}

static void LGLogCatalogAddDirectory(NSMutableArray *entries, NSMutableSet *knownPaths, NSString *directory, NSString *displayPrefix, LGLogSource source)
{
    for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL])
    {
        if ([name hasPrefix:@"."])
            continue;
        LGLogCatalogAddEntry(entries, knownPaths, [directory stringByAppendingPathComponent:name], [displayPrefix stringByAppendingPathComponent:name], source);
    }
}

static bool LGLogCatalogBytesContain(const uint8_t *bytes, size_t length, const char *token)
{
    size_t tokenLength = strlen(token);
    if (tokenLength == 0 || tokenLength > length)
        return false;
    const uint8_t *cursor = bytes;
    const uint8_t *last = bytes + length - tokenLength;
    while (cursor <= last)
    {
        const uint8_t *candidate = memchr(cursor, token[0], (size_t)(last - cursor) + 1);
        if (candidate == NULL)
            return false;
        if (memcmp(candidate, token, tokenLength) == 0)
            return true;
        cursor = candidate + 1;
    }
    return false;
}

static NSData *LGLogCatalogReadFile(NSString *path, unsigned long long limit)
{
    struct stat info;
    if (stat(path.fileSystemRepresentation, &info) != 0 || !S_ISREG(info.st_mode) || (unsigned long long)info.st_size > limit)
        return nil;
    return [[NSData alloc] initWithContentsOfFile:path];
}

static bool LGLogCatalogFileContainsAny(NSString *path, const char *const *tokens, size_t count)
{
    NSData *data = LGLogCatalogReadFile(path, LGLogCatalogSystemReportInspectionLimit);
    if (data.length == 0)
        return false;
    for (size_t index = 0; index < count; index++)
    {
        if (LGLogCatalogBytesContain((const uint8_t *)data.bytes, data.length, tokens[index]))
            return true;
    }
    return false;
}

static bool LGLogCatalogIsReportName(NSString *lowercaseName)
{
    return [lowercaseName rangeOfString:@".crash"].location != NSNotFound || [lowercaseName rangeOfString:@".ips"].location != NSNotFound || [lowercaseName rangeOfString:@".plist"].location != NSNotFound;
}

static bool LGLogCatalogSystemReportBelongsToLightGram(NSString *path, NSString *lowercaseName)
{
    static const char *const bundleTokens[] = { LGHelperApplicationBundleIdentifier };
    static const char *const processTokens[] = {
        LGHelperApplicationBundleIdentifier,
        "\"lightgramd\"", ">lightgramd<",
        "\"LightGram\"", ">LightGram<",
        "\"Telegram\"", ">Telegram<",
        "\"Telegram" LGSystemApplicationBinarySuffix "\"", ">Telegram" LGSystemApplicationBinarySuffix "<"
    };
    static const char *const settingsTokens[] = { "LightGramHelper" };

    if ([lowercaseName hasPrefix:@"lightgramd"])
        return true;
    if ([lowercaseName hasPrefix:@"telegram"] || [lowercaseName hasPrefix:@"lightgram"])
        return LGLogCatalogFileContainsAny(path, bundleTokens, sizeof(bundleTokens) / sizeof(bundleTokens[0]));
    if ([lowercaseName hasPrefix:@"lowmemory"] || [lowercaseName hasPrefix:@"jetsamevent"])
        return LGLogCatalogFileContainsAny(path, processTokens, sizeof(processTokens) / sizeof(processTokens[0]));
    if ([lowercaseName hasPrefix:@"preferences"])
        return LGLogCatalogFileContainsAny(path, settingsTokens, sizeof(settingsTokens) / sizeof(settingsTokens[0]));
    return false;
}

static NSString *LGLogCatalogDecodeText(NSData *data)
{
    if (data.length == 0)
        return @"";
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (text == nil)
        text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    return text ?: @"";
}

static NSString *LGLogCatalogPropertyListText(NSData *data)
{
    NSString *errorDescription = nil;
    NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
    id propertyList = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&errorDescription];
    if (propertyList == nil)
        return nil;

    NSMutableString *text = [[NSMutableString alloc] init];
    id description = [propertyList isKindOfClass:[NSDictionary class]] ? [propertyList objectForKey:@"description"] : nil;
    if ([description isKindOfClass:[NSString class]])
    {
        NSArray *keys = [[propertyList allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *key in keys)
        {
            id value = [propertyList objectForKey:key];
            if ([key isEqual:@"description"] || !([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSDate class]]))
                continue;
            [text appendFormat:@"%@: %@\n", key, value];
        }
        if (text.length != 0)
            [text appendString:@"\n"];
        [text appendString:description];
        return text;
    }

    NSData *xml = [NSPropertyListSerialization dataFromPropertyList:propertyList format:NSPropertyListXMLFormat_v1_0 errorDescription:&errorDescription];
    return xml == nil ? nil : LGLogCatalogDecodeText(xml);
}

static NSData *LGLogCatalogReadTail(NSString *path, NSUInteger maximumLength, bool *truncated)
{
    int fd = open(path.fileSystemRepresentation, O_RDONLY);
    if (fd < 0)
        return nil;
    struct stat info;
    if (fstat(fd, &info) != 0 || !S_ISREG(info.st_mode))
    {
        close(fd);
        return nil;
    }
    unsigned long long size = (unsigned long long)info.st_size;
    unsigned long long start = size > maximumLength ? size - maximumLength : 0;
    if (lseek(fd, (off_t)start, SEEK_SET) < 0)
    {
        close(fd);
        return nil;
    }
    NSMutableData *data = [[NSMutableData alloc] initWithLength:(NSUInteger)(size - start)];
    NSUInteger total = 0;
    while (total < data.length)
    {
        ssize_t count = read(fd, (uint8_t *)data.mutableBytes + total, data.length - total);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            break;
        total += (NSUInteger)count;
    }
    close(fd);
    [data setLength:total];

    if (start != 0)
    {
        const uint8_t *newline = memchr(data.bytes, '\n', data.length);
        if (newline != NULL)
            [data replaceBytesInRange:NSMakeRange(0, (NSUInteger)(newline - (const uint8_t *)data.bytes) + 1) withBytes:NULL length:0];
    }
    if (truncated != NULL)
        *truncated = start != 0;
    return data;
}

@implementation LGLogCatalog

+ (NSString *)systemApplicationDocumentsPath
{
    return @LGSystemApplicationMobileHomePath "/" LGSystemApplicationHomeRelativePath "/Documents";
}

+ (NSArray *)installedApplicationDocumentsPaths
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *bundleIdentifier = @LGHelperApplicationBundleIdentifier;
    NSMutableArray *paths = [[NSMutableArray alloc] init];
    BOOL isDirectory = false;

    NSString *systemDocuments = [self systemApplicationDocumentsPath];
    if ([fileManager fileExistsAtPath:systemDocuments isDirectory:&isDirectory] && isDirectory)
        [paths addObject:systemDocuments];

    NSString *containers = @"/var/mobile/Containers/Data/Application";
    for (NSString *entry in [fileManager contentsOfDirectoryAtPath:containers error:NULL])
    {
        NSString *container = [containers stringByAppendingPathComponent:entry];
        NSDictionary *metadata = [[NSDictionary alloc] initWithContentsOfFile:[container stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
        if ([[metadata objectForKey:@"MCMMetadataIdentifier"] isEqual:bundleIdentifier])
            [paths addObject:[container stringByAppendingPathComponent:@"Documents"]];
    }

    NSString *legacyApplications = @"/var/mobile/Applications";
    for (NSString *entry in [fileManager contentsOfDirectoryAtPath:legacyApplications error:NULL])
    {
        NSString *container = [legacyApplications stringByAppendingPathComponent:entry];
        for (NSString *name in [fileManager contentsOfDirectoryAtPath:container error:NULL])
        {
            if (![[name pathExtension] isEqualToString:@"app"])
                continue;
            NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:[[container stringByAppendingPathComponent:name] stringByAppendingPathComponent:@"Info.plist"]];
            if ([[info objectForKey:@"CFBundleIdentifier"] isEqual:bundleIdentifier])
            {
                [paths addObject:[container stringByAppendingPathComponent:@"Documents"]];
                break;
            }
        }
    }
    return paths;
}

+ (NSArray *)applicationEntriesWithDocumentsPath:(NSString *)documentsPath
{
    NSMutableArray *entries = [[NSMutableArray alloc] init];
    if (documentsPath.length == 0)
        return entries;
    NSMutableSet *knownPaths = [[NSMutableSet alloc] init];

    for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsPath error:NULL])
    {
        bool applicationLog = [name hasPrefix:@"application-"] && [name hasSuffix:@".log"];
        bool breadcrumbs = [name hasPrefix:@"ios6_diagnostic_breadcrumbs"] && [name hasSuffix:@".log"];
        if (applicationLog || breadcrumbs || [name isEqualToString:@"ios6_last_crash.txt"] || [name isEqualToString:@"launch-order.txt"])
            LGLogCatalogAddEntry(entries, knownPaths, [documentsPath stringByAppendingPathComponent:name], name, LGLogSourceLightGram);
    }
    LGLogCatalogAddDirectory(entries, knownPaths, [documentsPath stringByAppendingPathComponent:@"LightGramLogs"], @"LightGramLogs", LGLogSourceLightGram);
    LGLogCatalogAddDirectory(entries, knownPaths, [documentsPath stringByAppendingPathComponent:@"calls"], @"calls", LGLogSourceLightGram);
    NSString *home = [documentsPath stringByDeletingLastPathComponent];
    LGLogCatalogAddDirectory(entries, knownPaths, [home stringByAppendingPathComponent:@"Library/LightGramPlugins/logs"], @"plugins", LGLogSourceLightGram);

    [entries sortUsingSelector:@selector(compareNewestFirst:)];
    return entries;
}

+ (NSArray *)helperEntries
{
    NSMutableArray *entries = [[NSMutableArray alloc] init];
    NSMutableSet *knownPaths = [[NSMutableSet alloc] init];
    for (NSString *path in @[@LGHelperLogPath, @LGHelperRotatedLogPath, @LGHelperStandardErrorLogPath])
        LGLogCatalogAddEntry(entries, knownPaths, path, path.lastPathComponent, LGLogSourceHelper);
    [entries sortUsingSelector:@selector(compareNewestFirst:)];
    return entries;
}

+ (NSArray *)systemEntriesWithAdditionalDirectories:(NSArray *)directories
{
    NSMutableArray *entries = [[NSMutableArray alloc] init];
    NSMutableSet *knownPaths = [[NSMutableSet alloc] init];
    NSMutableArray *searchDirectories = [[NSMutableArray alloc] initWithObjects:@LGHelperCrashReporterPath, @LGHelperCrashReporterPath "/Retired", nil];
    if (directories != nil)
        [searchDirectories addObjectsFromArray:directories];

    for (NSString *directory in searchDirectories)
    {
        NSString *displayPrefix = [directory hasPrefix:@LGHelperCrashReporterPath "/"] ? [directory substringFromIndex:[@LGHelperCrashReporterPath "/" length]] : @"";
        for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL])
        {
            NSString *lowercaseName = name.lowercaseString;
            if (!LGLogCatalogIsReportName(lowercaseName))
                continue;
            NSString *path = [directory stringByAppendingPathComponent:name];
            if (!LGLogCatalogSystemReportBelongsToLightGram(path, lowercaseName))
                continue;
            LGLogCatalogAddEntry(entries, knownPaths, path, displayPrefix.length == 0 ? name : [displayPrefix stringByAppendingPathComponent:name], LGLogSourceSystem);
        }
    }
    [entries sortUsingSelector:@selector(compareNewestFirst:)];
    return entries;
}

+ (NSArray *)entriesWithDocumentsPaths:(NSArray *)documentsPaths
{
    NSMutableArray *entries = [[NSMutableArray alloc] init];
    NSMutableSet *knownPaths = [[NSMutableSet alloc] init];
    NSMutableArray *localCrashDirectories = [[NSMutableArray alloc] init];
    NSMutableArray *groups = [[NSMutableArray alloc] init];
    for (NSString *documentsPath in documentsPaths)
    {
        [groups addObject:[self applicationEntriesWithDocumentsPath:documentsPath]];
        [localCrashDirectories addObject:[[documentsPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Library/Logs/CrashReporter"]];
    }
    [groups addObject:[self helperEntries]];
    [groups addObject:[self systemEntriesWithAdditionalDirectories:localCrashDirectories]];
    for (NSArray *group in groups)
    {
        for (LGLogEntry *entry in group)
        {
            if ([knownPaths containsObject:entry.path])
                continue;
            [knownPaths addObject:entry.path];
            [entries addObject:entry];
        }
    }
    return entries;
}

+ (NSString *)textAtPath:(NSString *)path maximumLength:(NSUInteger)maximumLength truncated:(bool *)truncated
{
    if (truncated != NULL)
        *truncated = false;
    if ([[path.pathExtension lowercaseString] isEqualToString:@"plist"])
    {
        NSData *data = LGLogCatalogReadFile(path, LGLogCatalogFullTextLimit);
        NSString *text = data == nil ? nil : LGLogCatalogPropertyListText(data);
        if (text != nil)
        {
            if (text.length > maximumLength)
            {
                if (truncated != NULL)
                    *truncated = true;
                return [text substringFromIndex:text.length - maximumLength];
            }
            return text;
        }
    }
    NSData *data = LGLogCatalogReadTail(path, maximumLength, truncated);
    return data == nil ? nil : LGLogCatalogDecodeText(data);
}

+ (NSString *)fullTextAtPath:(NSString *)path
{
    return [self textAtPath:path maximumLength:LGLogCatalogFullTextLimit truncated:NULL];
}

@end
