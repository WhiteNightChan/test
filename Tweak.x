#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTIItemSectionRenderer.h>
#import <YouTubeHeader/YTIItemSectionSupportedRenderers.h>
#import <YouTubeHeader/YTInnerTubeCollectionViewController.h>

@interface YTIElementRendererCompatibilityOptions (YTX)
- (BOOL)useBackstageCellControllerOnIos;
@end

static NSArray *YTXFilteredSections(NSArray *sections) {
    NSMutableArray *filtered = [sections mutableCopy];

    for (YTIItemSectionRenderer *section in [filtered copy]) {
        if (![section isKindOfClass:%c(YTIItemSectionRenderer)])
            continue;

        NSMutableArray *contents = [section.contentsArray mutableCopy];

        NSIndexSet *removeIndexes =
            [contents indexesOfObjectsPassingTest:
                ^BOOL(YTIItemSectionSupportedRenderers *item,
                      NSUInteger idx,
                      BOOL *stop) {

            YTIElementRenderer *renderer = item.elementRenderer;

            if (!renderer)
                return NO;

            if (![renderer respondsToSelector:
                    @selector(compatibilityOptions)])
                return NO;

            id options = renderer.compatibilityOptions;

            if (!options)
                return NO;

            if (![options respondsToSelector:
                    @selector(useBackstageCellControllerOnIos)])
                return NO;

            return [options useBackstageCellControllerOnIos];
        }];

        [contents removeObjectsAtIndexes:removeIndexes];

        section.contentsArray = contents;
    }

    return filtered;
}

%hook YTInnerTubeCollectionViewController

- (void)addSectionsFromArray:(NSArray *)array {
    %orig(YTXFilteredSections(array));
}

%end