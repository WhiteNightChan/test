#import <Foundation/Foundation.h>

%hook YTMutableCellFactory

- (id)cellControllerForEntry:(id)entry
             parentResponder:(id)parentResponder
{
    if (entry &&
        [[entry description] containsString:@"images_post_responsive_root.eml"]) {
        return nil;
    }

    return %orig;
}

%end