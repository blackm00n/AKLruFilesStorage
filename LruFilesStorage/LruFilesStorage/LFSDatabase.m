//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

#import "LFSDatabase.h"
#import "FMDatabase.h"
#import "LFSDatabaseRecord.h"


NSString* const LFSDatabaseException = @"com.akozhevnikov.LFSDatabaseException";


static const long SupportedVersion = 1;


#define TABLE_DB_INFO @"db_info"
#define COLUMN_TOTAL_SIZE @"total_size"
#define COLUMN_VERSION @"version"

static NSString* const kCreateDbInfoTable = @"CREATE TABLE IF NOT EXISTS "TABLE_DB_INFO" ("COLUMN_TOTAL_SIZE" INTEGER, "COLUMN_VERSION" INTEGER)";
static NSString* const kInitDbInfoTable = @"INSERT INTO "TABLE_DB_INFO" VALUES(?, ?)";
static NSString* const kFetchVersion = @"SELECT "COLUMN_VERSION" FROM "TABLE_DB_INFO;
static NSString* const kFetchTotalSize = @"SELECT "COLUMN_TOTAL_SIZE" FROM "TABLE_DB_INFO;
static NSString* const kUpdateTotalSize = @"UPDATE " TABLE_DB_INFO " SET "COLUMN_TOTAL_SIZE"=?";


#define TABLE_RECORDS @"records"
#define INDEX_KEY @"key_index"
#define COLUMN_LAST_ACCESS_TIME @"last_access_time"
#define COLUMN_FILE_NAME @"file_name"
#define COLUMN_KEY @"key"
#define COLUMN_SIZE @"size"

static NSString* const kCreateRecordsTable = @"CREATE TABLE IF NOT EXISTS "TABLE_RECORDS" ("COLUMN_LAST_ACCESS_TIME" REAL, "COLUMN_FILE_NAME" TEXT NOT NULL, "COLUMN_SIZE" INTEGER, "COLUMN_KEY" TEXT NOT NULL, UNIQUE ("COLUMN_FILE_NAME", "COLUMN_KEY"));";
static NSString* const kCreateRecordsIndexByKey = @"CREATE INDEX IF NOT EXISTS "INDEX_KEY" ON "TABLE_RECORDS" ("COLUMN_KEY")";
static NSString* const kFetchRecordByKey = @"SELECT * FROM "TABLE_RECORDS" WHERE "COLUMN_KEY"=?";
static NSString* const kInsertRecord = @"INSERT INTO "TABLE_RECORDS" VALUES(?, ?, ?, ?)";
static NSString* const kFetchLruRecordsBatch = @"SELECT * FROM "TABLE_RECORDS" ORDER BY "COLUMN_LAST_ACCESS_TIME" ASC LIMIT ?";
static NSString* const kUpdateLastAccessTimeForRecord = @"UPDATE "TABLE_RECORDS" SET "COLUMN_LAST_ACCESS_TIME"=? WHERE "COLUMN_KEY"=?";
static NSString* const kDeleteRecord = @"DELETE FROM "TABLE_RECORDS" WHERE "COLUMN_KEY"=?";

@interface LFSDatabase()

@property(nonatomic) FMDatabase* db;

@end

@implementation LFSDatabase

- (instancetype)initWithDirectoryPath:(NSString*)directoryPath
{
    self = [super init];
    if (self == nil) {
        return nil;
    }

    NSString* databaseFilePath = [[directoryPath stringByAppendingPathComponent:@"LFSDatabase"] stringByAppendingPathExtension:@"sqlite"];
    _db = [FMDatabase databaseWithPath:databaseFilePath];
    if (![_db open]) {
        [NSException raise:LFSDatabaseException format:@"Failed to open database"];
    }

    NSError* error = nil;
    if (![_db executeUpdate:kCreateDbInfoTable withErrorAndBindings:&error]) {
        [NSException raise:LFSDatabaseException format:@"Failed to create '"TABLE_DB_INFO"' table: %@", error];
    }
    FMResultSet* resultSet = [_db executeQuery:kFetchVersion];
    if (resultSet == nil) {
        [NSException raise:LFSDatabaseException format:@"Failed to fetch version: %@", _db.lastError];
    }
    if ([resultSet nextWithError:&error]) {
        const long version = [resultSet longForColumn:COLUMN_VERSION];
        if (version > SupportedVersion) {
            [NSException raise:LFSDatabaseException format:@"Database version %@ is larger than supported version %@", @(version), @(SupportedVersion)];
        } else {
            // handle upgrade
        }
    } else {
        if (![_db executeUpdate:kInitDbInfoTable withErrorAndBindings:&error, @(0), @(SupportedVersion)]) {
            [NSException raise:LFSDatabaseException format:@"Failed to initialize '"TABLE_DB_INFO"' table: %@", error];
        }
    }
    if (![_db executeUpdate:kCreateRecordsTable withErrorAndBindings:&error]) {
        [NSException raise:LFSDatabaseException format:@"Failed to create '"TABLE_RECORDS"' table: %@", error];
    }
    if (![_db executeUpdate:kCreateRecordsIndexByKey withErrorAndBindings:&error]) {
        [NSException raise:LFSDatabaseException format:@"Failed to create '"INDEX_KEY"' table: %@", error];
    }

    return self;
}

- (void)updateTotalSize:(int64_t)totalSize
{
    NSError* error = nil;
    if (![_db executeUpdate:kUpdateTotalSize withErrorAndBindings:&error, @(totalSize)]) {
        [NSException raise:LFSDatabaseException format:@"Failed to change total size: %@", error];
    }
}

- (int64_t)fetchTotalSize
{
    NSError* error = nil;
    FMResultSet* resultSet = [self.db executeQuery:kFetchTotalSize];
    if (resultSet != nil) {
        while ([resultSet nextWithError:&error]) {
            return [resultSet longLongIntForColumn:COLUMN_TOTAL_SIZE];
        }
    }
    [NSException raise:LFSDatabaseException format:@"Failed to fetch total size: %@", self.db.lastError];
    return 0;
}

- (void)insertRecordWithKey:(NSString*)key fileName:(NSString*)fileName size:(int64_t)size
{
    NSError* error = nil;
    if (![self.db executeUpdate:kInsertRecord withErrorAndBindings:&error, @([[NSDate date] timeIntervalSince1970]), fileName, @(size), key]) {
        [NSException raise:LFSDatabaseException format:@"Failed to update '"TABLE_RECORDS"' table: %@", error];
    }
}

- (void)deleteRecordWithKey:(NSString*)key
{
    NSError* error = nil;
    if (![self.db executeUpdate:kDeleteRecord withErrorAndBindings:&error, key]) {
        [NSException raise:LFSDatabaseException format:@"Failed to delete record: %@", error];
    }
}

- (NSArray*)fetchMruRecordsOfBatchSize:(NSUInteger)batchSize
{
    NSMutableArray* result = [NSMutableArray array];

    FMResultSet* resultSet = [self.db executeQuery:kFetchLruRecordsBatch, @(batchSize)];

    NSError* error = nil;
    while ([resultSet nextWithError:&error]) {
        LFSDatabaseRecord* record = [[LFSDatabaseRecord alloc] initWithFileName:[resultSet stringForColumn:COLUMN_FILE_NAME]
                                                                            key:[resultSet stringForColumn:COLUMN_KEY]
                                                                 lastAccessTime:[NSDate dateWithTimeIntervalSince1970:[resultSet doubleForColumn:COLUMN_LAST_ACCESS_TIME]]
                                                                           size:[resultSet longLongIntForColumn:COLUMN_SIZE]];
        [result addObject:record];
    }

    if (error != nil) {
        [NSException raise:LFSDatabaseException format:@"Failed to fetch MRU records: %@", error];
    }

    return [result copy];
}

- (void)updateLastAccessTime:(NSDate*)lastAccessTime forRecordWithKey:(NSString*)key
{
    NSError* error = nil;
    if (![self.db executeUpdate:kUpdateLastAccessTimeForRecord withErrorAndBindings:&error, @([lastAccessTime timeIntervalSince1970]), key]) {
        [NSException raise:LFSDatabaseException format:@"Failed to apply deferred timestamp: %@", error];
    }
}

- (LFSDatabaseRecord*)fetchRecordForKey:(NSString*)key
{
    FMResultSet* resultSet = [self.db executeQuery:kFetchRecordByKey, key];

    NSError* error = nil;
    while ([resultSet nextWithError:&error]) {
        return [[LFSDatabaseRecord alloc] initWithFileName:[resultSet stringForColumn:COLUMN_FILE_NAME]
                                                       key:[resultSet stringForColumn:COLUMN_KEY]
                                            lastAccessTime:[NSDate dateWithTimeIntervalSince1970:[resultSet doubleForColumn:COLUMN_LAST_ACCESS_TIME]]
                                                      size:[resultSet longLongIntForColumn:COLUMN_SIZE]];
    }

    if (error != nil) {
        [NSException raise:LFSDatabaseException format:@"Error while fetching record for key: %@", error];
    }

    return nil;
}

- (void)dealloc
{
    [self.db close];
}

- (void)doInTransaction:(void (^)())block
{
    if (![self.db beginTransaction]) {
        [NSException raise:LFSDatabaseException format:@"Failed to begin transaction: %@", self.db.lastError];
    }
    if (block != nil) {
        block();
    }
    if (![self.db commit]) {
        [NSException raise:LFSDatabaseException format:@"Failed to commit transaction: %@", self.db.lastError];
    }
}

@end