//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

#import <Foundation/Foundation.h>
#import "LFSRecord.h"


@interface LFSDatabaseRecord : LFSRecord

- (instancetype)initWithFileName:(NSString*)fileName key:(NSString*)key lastAccessTime:(NSDate*)lastAccessTime size:(int64_t)size;

@property(nonatomic, readonly) NSDate* lastAccessTime;
@property(nonatomic, readonly) int64_t size;

@end