//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

#import "LFSDatabaseRecord.h"


@implementation LFSDatabaseRecord

- (instancetype)initWithFileName:(NSString*)fileName key:(NSString*)key lastAccessTime:(NSDate*)lastAccessTime size:(int64_t)size
{
    self = [super initWithFileName:fileName key:key];
    if (self == nil) {
        return nil;
    }

    _lastAccessTime = lastAccessTime;
    _size = size;

    return self;
}

@end