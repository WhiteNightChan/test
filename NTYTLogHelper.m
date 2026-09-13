#import "NTYTLogHelper.h"

@implementation NTYTLogHelper

+ (NSString *)logFilePath {
    static NSString *path = nil;

    @synchronized(self) {
        if (!path) {
            NSString *version =
                [[NSBundle mainBundle]
                    objectForInfoDictionaryKey:
                        @"CFBundleShortVersionString"];

            if (![version isKindOfClass:[NSString class]] ||
                version.length == 0) {

                version = @"unknown";
            }

            NSDateFormatter *formatter =
                [[NSDateFormatter alloc] init];

            formatter.locale =
                [[NSLocale alloc]
                    initWithLocaleIdentifier:@"en_US_POSIX"];

            formatter.calendar =
                [[NSCalendar alloc]
                    initWithCalendarIdentifier:
                        NSCalendarIdentifierGregorian];

            formatter.timeZone =
                [NSTimeZone localTimeZone];

            formatter.dateFormat =
                @"yyyyMMdd-HHmmss";

            NSString *timestamp =
                [formatter stringFromDate:[NSDate date]];

            NSString *fileName =
                [NSString stringWithFormat:
                    @"NoThankYouTube-log_v%@_%@.txt",
                    version,
                    timestamp];

            path =
                [NSTemporaryDirectory()
                    stringByAppendingPathComponent:fileName];
        }
    }

    return path;
}

+ (void)appendLine:(NSString *)line {
    @synchronized(self) {
        @try {
            NSString *path = [self logFilePath];

            NSString *text =
                [[line ?: @"(nil)"
                    stringByAppendingString:@"\n"] copy];

            NSData *data =
                [text dataUsingEncoding:NSUTF8StringEncoding];

            if (!data) {
                return;
            }

            if (![[NSFileManager defaultManager]
                    fileExistsAtPath:path]) {

                [[NSFileManager defaultManager]
                    createFileAtPath:path
                    contents:data
                    attributes:nil];
                return;
            }

            NSFileHandle *handle =
                [NSFileHandle fileHandleForWritingAtPath:path];

            if (!handle) {
                [[NSFileManager defaultManager]
                    createFileAtPath:path
                    contents:data
                    attributes:nil];
                return;
            }

            [handle seekToEndOfFile];
            [handle writeData:data];
            [handle closeFile];

        } @catch (__unused NSException *exception) {
        }
    }
}

+ (void)clearLogFile {
    @synchronized(self) {
        NSString *path = [self logFilePath];

        if ([[NSFileManager defaultManager]
                fileExistsAtPath:path]) {

            [[NSFileManager defaultManager]
                removeItemAtPath:path
                error:nil];
        }
    }
}

@end

void NTYTLog(NSString *format, ...) {
    if (!format) {
        format = @"(nil)";
    }

    va_list args;
    va_start(args, format);

    NSString *line =
        [[NSString alloc] initWithFormat:format
                              arguments:args];

    va_end(args);

    /*
     * Keep normal NSLog output for device/syslog visibility,
     * and mirror the same formatted line to the NTYT log file.
     */
    NSLog(@"%@", line ?: @"(nil)");
    [NTYTLogHelper appendLine:line];
}
