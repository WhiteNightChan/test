#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface YTMutableCellFactory : NSObject
- (id)cellControllerForEntry:(id)entry
             parentResponder:(id)parentResponder;
@end

%hook YTMutableCellFactory

- (id)cellControllerForEntry:(id)entry
             parentResponder:(id)parentResponder
{
    id result = %orig;

    if (result &&
        [NSStringFromClass([result class]) isEqualToString:@"YTCommentElementCellController"]) {

        NSString *description = [entry description];

        if ([description containsString:@"images_post_responsive_root.eml"]) {
            return nil;
        }
    }

    return result;
}

%end