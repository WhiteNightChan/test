#import <Foundation/Foundation.h>

@interface YTIElementRenderer : NSObject
- (id)compatibilityOptions;
@end

@interface YTCompatibilityOptions : NSObject
- (BOOL)useBackstageCellControllerOnIos;
@end


static BOOL YTIsCommunityPostEntry(id entry)
{
    Class cls = %c(YTIElementRenderer);

    if (!cls || ![entry isKindOfClass:cls])
        return NO;

    id options = [(YTIElementRenderer *)entry compatibilityOptions];

    return [(YTCompatibilityOptions *)options useBackstageCellControllerOnIos];
}


%hook YTMutableCellFactory

- (id)cellControllerForEntry:(id)entry
             parentResponder:(id)parentResponder
{
    if (YTIsCommunityPostEntry(entry)) {
        return nil;
    }

    return %orig;
}

%end


%hook YTFeedSectionController

- (id)createCellControllerForEntry:(id)entry
{
    if (YTIsCommunityPostEntry(entry)) {
        return nil;
    }

    return %orig;
}

%end