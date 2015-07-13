//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

#import <Foundation/Foundation.h>

@class LFSDatabaseRecord;


extern NSString* const LFSDatabaseException;


@interface LFSDatabase : NSObject

- (instancetype)initWithDirectoryPath:(NSString*)directoryPath;

- (void)updateTotalSize:(int64_t)totalSize;

- (int64_t)fetchTotalSize;

- (void)insertRecordWithKey:(NSString*)key fileName:(NSString*)fileName size:(int64_t)size;

- (void)deleteRecordWithKey:(NSString*)key;

- (NSArray*)fetchMruRecordsOfBatchSize:(NSUInteger)batchSize;

- (void)updateLastAccessTime:(NSDate*)lastAccessTime forRecordWithKey:(NSString*)key;

- (LFSDatabaseRecord*)fetchRecordForKey:(NSString*)key;

@end