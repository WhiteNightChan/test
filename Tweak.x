#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTISectionListRenderer.h>
#import <YouTubeHeader/YTIShelfRenderer.h>
#import <YouTubeHeader/YTInnerTubeCollectionViewController.h>
#import <HBLog.h>

@interface YTIElementRendererCompatibilityOptions (NTYT)
- (BOOL)useVideoCellControllerOnIos;
@end

NSString *getVideoString(NSString *description) {
    for (NSString *str in @[
        // videoId?
        // channelName?
        // title?
        // viewCount?
        // channelId?
    ])
        if ([description containsString:str]) return str;

    return nil;
}

static BOOL isVideoRenderer(YTIElementRenderer *elementRenderer, int kind) {

    // Primary: useVideoCellControllerOnIos
    if ([elementRenderer respondsToSelector:@selector(hasCompatibilityOptions)] && elementRenderer.hasCompatibilityOptions && elementRenderer.compatibilityOptions.useVideoCellControllerOnIos) {
        HBLogDebug(@"NTYT adLogging %d %@", kind, elementRenderer);
        return YES;
    }

    // Fallback: ElementRenderer.description EML
    NSString *description = [elementRenderer description];
    NSString *postString = getVideoString(description);
    if (postString) {
        HBLogDebug(@"NTYT getVideoString %d %@ %@", kind, postString, elementRenderer);
        return YES;
    }
    return NO;
}


// VideoをElement単位またはSection単位で除去する。
// useVideoCellControllerOnIosを主判定とし、EML descriptionをfallbackとして使用。
static NSMutableArray <YTIItemSectionRenderer *> *filteredArray(NSArray <YTIItemSectionRenderer *> *array) {
    NSMutableArray <YTIItemSectionRenderer *> *newArray = [array mutableCopy];
    NSIndexSet *removeIndexes = [newArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionRenderer *sectionRenderer, NSUInteger idx, BOOL *stop) {

        // Shelf.itemsArray ElementRenderer
        if ([sectionRenderer isKindOfClass:%c(YTIShelfRenderer)]) {
            YTIShelfSupportedRenderers *content = ((YTIShelfRenderer *)sectionRenderer).content;
            YTIHorizontalListRenderer *horizontalListRenderer = content.horizontalListRenderer;
            NSMutableArray <YTIHorizontalListSupportedRenderers *> *itemsArray = horizontalListRenderer.itemsArray;
            NSIndexSet *removeItemsArrayIndexes = [itemsArray indexesOfObjectsPassingTest:^BOOL(YTIHorizontalListSupportedRenderers *horizontalListSupportedRenderers, NSUInteger idx2, BOOL *stop2) {
                YTIElementRenderer *elementRenderer = horizontalListSupportedRenderers.elementRenderer;
                return isVideoRenderer(elementRenderer, 4);
            }];
            [itemsArray removeObjectsAtIndexes:removeItemsArrayIndexes];
        }
        if (![sectionRenderer isKindOfClass:%c(YTIItemSectionRenderer)])
            return NO;
        NSMutableArray <YTIItemSectionSupportedRenderers *> *contentsArray = sectionRenderer.contentsArray;

        // Section.contentsArray ElementRenderer
        // Section内に複数Elementがある場合は、Videoだけを個別除去
        if (contentsArray.count > 1) {
            NSIndexSet *removeContentsArrayIndexes = [contentsArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionSupportedRenderers *sectionSupportedRenderers, NSUInteger idx2, BOOL *stop2) {
                YTIElementRenderer *elementRenderer = sectionSupportedRenderers.elementRenderer;
                return isVideoRenderer(elementRenderer, 3);
            }];
            [contentsArray removeObjectsAtIndexes:removeContentsArrayIndexes];
        }

        // Fallback: SectionRenderer.description
        NSString *sectionDescription = [sectionRenderer description];
        NSString *sectionPostString = getVideoString(sectionDescription);
        if (sectionPostString) {
        HBLogDebug(@"NTYT sectionFallback %@ %@", sectionPostString, sectionRenderer);
            return YES;
        }

        // Section.firstObject ElementRenderer
        // VideoならSectionごと削除
        YTIItemSectionSupportedRenderers *firstObject = [contentsArray firstObject];
        YTIElementRenderer *elementRenderer = firstObject.elementRenderer;
        return isVideoRenderer(elementRenderer, 2);
    }];
    [newArray removeObjectsAtIndexes:removeIndexes];
    return newArray;
}

%hook YTInnerTubeCollectionViewController

- (void)displaySectionsWithReloadingSectionControllerByRenderer:(id)renderer {
    NSMutableArray *sectionRenderers = [self valueForKey:@"_sectionRenderers"];
    [self setValue:filteredArray(sectionRenderers) forKey:@"_sectionRenderers"];
    %orig;
}

- (void)addSectionsFromArray:(NSArray <YTIItemSectionRenderer *> *)array {
    %orig(filteredArray(array));
}

%end