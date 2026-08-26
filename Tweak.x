#import <Foundation/Foundation.h>
#import <objc/message.h>

@interface YTIElementRenderer : NSObject
- (id)compatibilityOptions;
@end

@interface YTCompatibilityOptions : NSObject
- (BOOL)useBackstageCellControllerOnIos;
@end

%hook YTFeedSectionController

- (id)createCellControllerForEntry:(id)entry {
    if ([entry isKindOfClass:%c(YTIElementRenderer)]) {
        YTCompatibilityOptions *options =
            (YTCompatibilityOptions *)[entry compatibilityOptions];

        if ([options useBackstageCellControllerOnIos]) {
            return nil;
        }
    }

    return %orig;
}

%end