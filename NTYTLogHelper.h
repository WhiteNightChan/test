#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NTYTLogHelper : NSObject

+ (NSString *)logFilePath;
+ (void)appendLine:(nullable NSString *)line;
+ (void)clearLogFile;

@end

FOUNDATION_EXPORT void NTYTLog(NSString *format, ...)
    NS_FORMAT_FUNCTION(1, 2);

NS_ASSUME_NONNULL_END
