#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTIElementRendererCompatibilityOptions.h>
#import <YouTubeHeader/YTIItemSectionRenderer.h>
#import <YouTubeHeader/YTIItemSectionSupportedRenderers.h>
#import <YouTubeHeader/YTIShelfRenderer.h>
#import <YouTubeHeader/YTIShelfSupportedRenderers.h>
#import <YouTubeHeader/YTIHorizontalListRenderer.h>
#import <YouTubeHeader/YTIHorizontalListSupportedRenderers.h>

@interface YTIElementRendererCompatibilityOptions (BBCPM)
- (BOOL)useBackstageCellControllerOnIos;
@end

static BOOL isCommunityPostRenderer(YTIElementRenderer *elementRenderer, int kind) {
    if ([elementRenderer respondsToSelector:@selector(hasCompatibilityOptions)] &&
        elementRenderer.hasCompatibilityOptions &&
        elementRenderer.compatibilityOptions.useBackstageCellControllerOnIos) {
        return YES;
    }

    return NO;
}

static NSMutableArray <YTIItemSectionRenderer *> *filteredArray(NSArray <YTIItemSectionRenderer *> *array) {
    NSMutableArray <YTIItemSectionRenderer *> *newArray = [array mutableCopy];
    NSIndexSet *removeIndexes = [newArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionRenderer *sectionRenderer, NSUInteger idx, BOOL *stop) {
        if ([sectionRenderer isKindOfClass:%c(YTIShelfRenderer)]) {
            YTIShelfSupportedRenderers *content = ((YTIShelfRenderer *)sectionRenderer).content;
            YTIHorizontalListRenderer *horizontalListRenderer = content.horizontalListRenderer;
            NSMutableArray <YTIHorizontalListSupportedRenderers *> *itemsArray = horizontalListRenderer.itemsArray;
            NSIndexSet *removeItemsArrayIndexes = [itemsArray indexesOfObjectsPassingTest:^BOOL(YTIHorizontalListSupportedRenderers *horizontalListSupportedRenderers, NSUInteger idx2, BOOL *stop2) {
                YTIElementRenderer *elementRenderer = horizontalListSupportedRenderers.elementRenderer;
                return isCommunityPostRenderer(elementRenderer, 4);
            }];
            [itemsArray removeObjectsAtIndexes:removeItemsArrayIndexes];
        }
        if (![sectionRenderer isKindOfClass:%c(YTIItemSectionRenderer)])
            return NO;
        NSMutableArray <YTIItemSectionSupportedRenderers *> *contentsArray = sectionRenderer.contentsArray;
        if (contentsArray.count > 1) {
            NSIndexSet *removeContentsArrayIndexes = [contentsArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionSupportedRenderers *sectionSupportedRenderers, NSUInteger idx2, BOOL *stop2) {
                YTIElementRenderer *elementRenderer = sectionSupportedRenderers.elementRenderer;
                return isCommunityPostRenderer(elementRenderer, 3);
            }];
            [contentsArray removeObjectsAtIndexes:removeContentsArrayIndexes];
        }
        YTIItemSectionSupportedRenderers *firstObject = [contentsArray firstObject];
        YTIElementRenderer *elementRenderer = firstObject.elementRenderer;
        return isCommunityPostRenderer(elementRenderer, 2);
    }];
    [newArray removeObjectsAtIndexes:removeIndexes];
    return newArray;
}

%hook YTInnerTubeCollectionViewController

- (void)addSectionsFromArray:(NSArray <YTIItemSectionRenderer *> *)array {
    %orig(filteredArray(array));
}

%end
