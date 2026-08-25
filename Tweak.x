#import <Foundation/Foundation.h>

%hook YTMutableCellFactory

- (id)cellControllerForEntry:(id)entry
             parentResponder:(id)parentResponder
{
    NSLog(@"[BBCPM] cellControllerForEntry: %@", entry);

    if (entry &&
        [[entry description] containsString:@"images_post_responsive_root.eml"]) {
        NSLog(@"[BBCPM] MATCH images_post_responsive_root.eml");
        return nil;
    }

    return %orig;
}

%end