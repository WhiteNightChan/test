#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - YTCommentElementCellController

@interface YTCommentElementCellController : NSObject
@end

%hook YTCommentElementCellController

- (id)init {
    NSLog(@"[YTCDT] YTCommentElementCellController init: %@", self);

    id ret = %orig;

    NSLog(@"[YTCDT] YTCommentElementCellController init -> %@", ret);

    return ret;
}

%end

#pragma mark - Tweak load test

%ctor {
    NSLog(@"[YTCDT] ===== Tweak loaded =====");

    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_source_t timer =
            dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                   dispatch_get_main_queue());

        dispatch_source_set_timer(
            timer,
            dispatch_time(DISPATCH_TIME_NOW, 0),
            NSEC_PER_SEC,
            0
        );

        dispatch_source_set_event_handler(timer, ^{
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";

            NSLog(@"[YTCDT] heartbeat: %@", [formatter stringFromDate:[NSDate date]]);
        });

        dispatch_resume(timer);
    });
}