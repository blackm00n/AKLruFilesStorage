//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

#import "LFSLogging.h"


@implementation LFSLogging

static void (^Logger)(NSString* log, LFSLogLevel level);

+ (void)setLogger:(void (^)(NSString* log, LFSLogLevel level))logger
{
    Logger = logger;
}

+ (void)log:(NSString*)format level:(LFSLogLevel)level, ...
{
    va_list argsList;
    va_start(argsList, level);
    NSString* string = [[NSString alloc] initWithFormat:format arguments:argsList];
    va_end(argsList);

    if (Logger != nil) {
        Logger(string, level);
    } else {
        NSLog(@"%@", string);
    }
}

@end