//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

#import <Foundation/Foundation.h>

extern NSString* const LruFilesStorageException;


@interface LFSDirectory : NSObject

- (instancetype)initWithPath:(NSString*)path
                maxTotalSize:(NSUInteger)maxTotalSize
                 maxFileSize:(NSUInteger)maxFileSize
               maxFilesCount:(NSUInteger)maxFilesCount;

- (NSString*)pathForKey:(NSString*)key;

- (NSString*)cacheFileWithPath:(NSString*)path forKey:(NSString*)key appendExtension:(NSString*)extension;

@end
