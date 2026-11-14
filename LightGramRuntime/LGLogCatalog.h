#import <Foundation/Foundation.h>

typedef enum {
    LGLogSourceLightGram = 0,
    LGLogSourceHelper = 1,
    LGLogSourceSystem = 2
} LGLogSource;

@interface LGLogEntry : NSObject

@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) LGLogSource source;
@property (nonatomic, readonly) NSDate *modificationDate;
@property (nonatomic, readonly) unsigned long long size;

- (NSComparisonResult)compareNewestFirst:(LGLogEntry *)other;

@end

@interface LGLogCatalog : NSObject

+ (NSArray *)installedApplicationDocumentsPaths;
+ (NSArray *)applicationEntriesWithDocumentsPath:(NSString *)documentsPath;
+ (NSArray *)helperEntries;
+ (NSArray *)systemEntriesWithAdditionalDirectories:(NSArray *)directories;
+ (NSArray *)entriesWithDocumentsPaths:(NSArray *)documentsPaths;

+ (NSString *)textAtPath:(NSString *)path maximumLength:(NSUInteger)maximumLength truncated:(bool *)truncated;
+ (NSString *)fullTextAtPath:(NSString *)path;

@end
