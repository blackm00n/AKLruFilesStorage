//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

#import "LFSDirectory.h"
#import "AKLruDictionary.h"
#import "AKThreadSafeLruDictionary.h"
#import "LFSLogging.h"
#import "LFSDatabase.h"
#import "LFSDatabaseRecord.h"


NSString* const LruFilesStorageException = @"com.akozhevnikov.LruFilesStorageException";


@interface LFSDirectory ()

@property(nonatomic, copy, readonly) NSString* path;
@property(nonatomic, readonly) NSUInteger highWaterTotalSize;
@property(nonatomic, readonly) NSUInteger lowWaterTotalSize;

@property(nonatomic, readonly) LFSDatabase* database;
@property(nonatomic, readonly) id <AKLruDictionary> memoryCache;
@property(nonatomic, readonly) NSMutableDictionary* deferredLastAccessTimes;

@end

@implementation LFSDirectory

- (instancetype)initWithPath:(NSString*)path
                maxTotalSize:(NSUInteger)maxTotalSize
                 maxFileSize:(NSUInteger)maxFileSize
               maxFilesCount:(NSUInteger)maxFilesCount
{
    NSParameterAssert(path.length > 0);

    self = [super init];
    if (self == nil) {
        return nil;
    }

    _highWaterTotalSize = maxTotalSize;
    _lowWaterTotalSize = maxTotalSize * 4 / 5;

    _path = [path copy];
    _memoryCache = [[AKThreadSafeLruDictionary alloc] initWithCountLimit:maxFilesCount
                                                      perObjectCostLimit:maxFileSize
                                                               costLimit:_lowWaterTotalSize / 2];
    _deferredLastAccessTimes = [NSMutableDictionary dictionary];

    NSError* error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error]) {
        [NSException raise:LruFilesStorageException format:@"Failed to create directory: %@", error];
    }

    _database = [[LFSDatabase alloc] initWithDirectoryPath:path];

    return self;
}

- (void)dealloc
{
    [self applyDeferredTimestamps];
}

- (NSString*)pathForKey:(NSString*)key
{
    NSString* fileName = nil;

    LFSRecord* memoryCacheRecord = [self.memoryCache objectForKey:key];
    if (memoryCacheRecord != nil) {
        fileName = [self processFoundRecord:memoryCacheRecord];
    } else {
        LFSDatabaseRecord* databaseRecord = [self.database fetchRecordForKey:key];
        if (databaseRecord == nil) {
            [self markNonExistentInMemoryCache:key];
        } else {
            fileName = [self processFoundRecord:databaseRecord];
        }
    }

    if (fileName != nil) {
        return [self.path stringByAppendingPathComponent:fileName];
    }

    return nil;
}

- (NSString*)processFoundRecord:(LFSRecord*)record
{
    if (record.fileName == nil) {
        return nil;
    } else {
        self.deferredLastAccessTimes[record.key] = [NSDate date];
        return record.fileName;
    }
}

- (void)markNonExistentInMemoryCache:(NSString*)key
{
    [self cacheInMemoryWithFileName:nil key:key fileSize:0];
}

- (void)cacheInMemoryWithFileName:(NSString*)fileName key:(NSString*)key fileSize:(int64_t)fileSize
{
    LFSRecord* memoryCacheRecord = [[LFSRecord alloc] initWithFileName:fileName key:key];
    [self.memoryCache setObject:memoryCacheRecord forKey:key cost:(NSUInteger) fileSize];
}

- (NSString*)cacheFileWithPath:(NSString*)path forKey:(NSString*)key appendExtension:(NSString*)extension
{
    NSError* fileError = nil;
    NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&fileError];
    if (attributes == nil) {
        return nil;
    }

    NSString* fileName = [[NSUUID new] UUIDString];
    if (extension.length > 0) {
        fileName = [fileName stringByAppendingPathExtension:extension];
    }

    NSString* permanentPath = [self.path stringByAppendingPathComponent:fileName];
    NSURL* permanentUrl = [NSURL fileURLWithPath:permanentPath];
    if (![[NSFileManager defaultManager] moveItemAtURL:[NSURL fileURLWithPath:path] toURL:permanentUrl error:&fileError]) {
        [LFSLogging log:@"Could not move file at %@ to %@ with error %@" level:LFSLogLevelError, path, permanentUrl, fileError];
        return nil;
    }

    [self applyDeferredTimestamps];

    int64_t fileSize = [attributes[NSFileSize] unsignedIntegerValue];
    [self cacheInMemoryWithFileName:fileName key:key fileSize:fileSize];
    [self drain:[self.database fetchTotalSize] + fileSize];

    [self.database insertRecordWithKey:key fileName:fileName size:fileSize];

    return permanentPath;
}

- (void)drain:(int64_t)totalSize
{
    if (totalSize > self.highWaterTotalSize) {
        [LFSLogging log:@"Freeing storage" level:LFSLogLevelTrace];

        const NSUInteger pageSize = 100;

        do {
            NSArray* mruRecords = [self.database fetchMruRecordsOfBatchSize:pageSize];

            for (LFSDatabaseRecord* record in mruRecords) {
                NSError* deletionError = nil;
                NSString* pathToDelete = [self.path stringByAppendingPathComponent:record.fileName];
                BOOL deletionResult = [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:pathToDelete]
                                                                                error:&deletionError];
                if (deletionResult || ([deletionError.domain isEqualToString:NSCocoaErrorDomain] && deletionError.code == NSFileNoSuchFileError)) {
                    totalSize -= record.size;
                    [self.database deleteRecordWithKey:record.key];
                } else {
                    [LFSLogging log:@"Failed to delete file: %@" level:LFSLogLevelError, deletionError];
                }

                if (totalSize < self.lowWaterTotalSize) {
                    break;
                }
            }

            if (mruRecords.count < pageSize || totalSize < self.lowWaterTotalSize) {
                [LFSLogging log:@"Drained %@ files, new total size is %@" level:LFSLogLevelTrace, @(mruRecords.count), @(totalSize)];
                break;
            }
        } while (YES);
    }

    [self.database updateTotalSize:totalSize];
}

-(void)applyDeferredTimestamps
{
    if (self.deferredLastAccessTimes.count == 0) {
        return;
    }

    for (NSString* key in self.deferredLastAccessTimes) {
        [self.database updateLastAccessTime:self.deferredLastAccessTimes[key] forRecordWithKey:key];
    }

    [self.deferredLastAccessTimes removeAllObjects];
}

@end
