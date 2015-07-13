//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

#import <Foundation/Foundation.h>


@interface LFSRecord : NSObject

- (instancetype)initWithFileName:(NSString*)fileName key:(NSString*)key;

@property(nonatomic, readonly) NSString* fileName;
@property(nonatomic, readonly) NSString* key;

@end