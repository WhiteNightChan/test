#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTISectionListRenderer.h>
#import <YouTubeHeader/YTIShelfRenderer.h>
#import <YouTubeHeader/YTInnerTubeCollectionViewController.h>
#import <HBLog.h>

@interface YTIElementRendererCompatibilityOptions (BBCPM)
- (BOOL)useBackstageCellControllerOnIos;
@end

NSString *getCommunityPostString(NSString *description) {
    for (NSString *str in @[
        @"post_base_wrapper.eml",
        @"post_base_wrapper_slim.eml",
        @"image_post_root.eml",
        @"images_post_root.eml",
        @"images_post_root_slim.eml",
        @"images_post_responsive_root.eml",
        @"text_post_root.eml",
        @"text_post_root_slim.eml",
        @"videos_post_root.eml",
        @"videos_post_responsive_root.eml",
        @"poll_post_root.eml",
        @"options_post_root.eml",
        @"options_post_responsive_root.eml"
    ])
        if ([description containsString:str]) return str;

    return nil;
}

static BOOL isCommunityPostRenderer(YTIElementRenderer *elementRenderer, int kind) {

    // Primary: useBackstageCellControllerOnIos
    if ([elementRenderer respondsToSelector:@selector(hasCompatibilityOptions)] && elementRenderer.hasCompatibilityOptions && elementRenderer.compatibilityOptions.useBackstageCellControllerOnIos) {
        HBLogDebug(@"BBCPM adLogging %d %@", kind, elementRenderer);
        return YES;
    }

    // Fallback: ElementRenderer.description EML
    NSString *description = [elementRenderer description];
    NSString *postString = getCommunityPostString(description);
    if (postString) {
        HBLogDebug(@"BBCPM getCommunityPostString %d %@ %@", kind, postString, elementRenderer);
        return YES;
    }
    return NO;
}


// Community PostをElement単位またはSection単位で除去する。
// useBackstageCellControllerOnIosを主判定とし、EML descriptionをfallbackとして使用。
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
                return isCommunityPostRenderer(elementRenderer, 4);
            }];
            [itemsArray removeObjectsAtIndexes:removeItemsArrayIndexes];
        }
        if (![sectionRenderer isKindOfClass:%c(YTIItemSectionRenderer)])
            return NO;
        NSMutableArray <YTIItemSectionSupportedRenderers *> *contentsArray = sectionRenderer.contentsArray;

        // Section.contentsArray ElementRenderer
        // Section内に複数Elementがある場合は、Community Postだけを個別除去
        if (contentsArray.count > 1) {
            NSIndexSet *removeContentsArrayIndexes = [contentsArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionSupportedRenderers *sectionSupportedRenderers, NSUInteger idx2, BOOL *stop2) {
                YTIElementRenderer *elementRenderer = sectionSupportedRenderers.elementRenderer;
                return isCommunityPostRenderer(elementRenderer, 3);
            }];
            [contentsArray removeObjectsAtIndexes:removeContentsArrayIndexes];
        }

        // Fallback: SectionRenderer.description
        NSString *sectionDescription = [sectionRenderer description];
        NSString *sectionPostString = getCommunityPostString(sectionDescription);
        if (sectionPostString) {
        HBLogDebug(@"BBCPM sectionFallback %@ %@", sectionPostString, sectionRenderer);
            return YES;
        }

        // Section.firstObject ElementRenderer
        // Community PostならSectionごと削除
        YTIItemSectionSupportedRenderers *firstObject = [contentsArray firstObject];
        YTIElementRenderer *elementRenderer = firstObject.elementRenderer;
        return isCommunityPostRenderer(elementRenderer, 2);
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