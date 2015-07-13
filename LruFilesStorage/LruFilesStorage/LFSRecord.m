//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

#import "LFSRecord.h"


@implementation LFSRecord

- (instancetype)initWithFileName:(NSString*)fileName key:(NSString*)key
{
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _fileName = fileName;
    _key = key;

    return self;
}

@end