//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(int32_t, LFSLogLevel) {
    LFSLogLevelError,
    LFSLogLevelTrace
};

@interface LFSLogging : NSObject

+ (void)setLogger:(void (^)(NSString* log, LFSLogLevel level))logger;

+ (void)log:(NSString*)format level:(LFSLogLevel)level, ...;

@end