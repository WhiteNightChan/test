#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTISectionListRenderer.h>
#import <YouTubeHeader/YTIShelfRenderer.h>
#import <YouTubeHeader/YTInnerTubeCollectionViewController.h>

#import "NTYTVideoIdentifier.h"
#import "NTYTVideoRuleBridge.h"

#import "NTYTLogHelper.h"

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
        NTYTLog(@"NTYT adLogging %d %@", kind, elementRenderer);
        return YES;
    }

    // Fallback: ElementRenderer.description EML
    NSString *description = [elementRenderer description];
    NSString *postString = getVideoString(description);
    if (postString) {
        NTYTLog(@"NTYT getVideoString %d %@ %@", kind, postString, elementRenderer);
        return YES;
    }
    return NO;
}

static BOOL shouldBlockStandaloneVideo(
    YTIElementRenderer *elementRenderer
) {
    /*
     * 既存判定を先に使う。
     *
     * metadata parser自体を
     * 「動画セル判定」には使用しない。
     */
    if (!isVideoRenderer(elementRenderer, 2)) {
        return NO;
    }

    NTYTVideoMetadata *metadata =
        NTYTVideoMetadataFromRenderer(elementRenderer);

    /*
     * 73080600 video_idが取れない特殊variant等は
     * 安全側で通す。
     */
    if (!metadata) {
        return NO;
    }

    /*
     * Phase 3:
     *
     * 旧 @"自作PC" 手動文字列判定を廃止し、
     * NTYTVideoMetadata を RuleEvaluator へ渡す。
     *
     * 現在のBridge側には検証用として
     * General contains "自作PC"
     * の固定Ruleが入っている。
     */
    return NTYTShouldBlockStandaloneVideoMetadata(metadata);
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
                return shouldBlockStandaloneVideo(elementRenderer);
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
                return shouldBlockStandaloneVideo(elementRenderer);
            }];
            [contentsArray removeObjectsAtIndexes:removeContentsArrayIndexes];

            /*
             * Multi-element sectionは各Elementを個別にRule評価済み。
             * 後段の「firstObjectがBLOCKならSectionごと削除」へ流さない。
             *
             * 全要素が消えた場合だけ空Section自体を削除する。
             */
            return contentsArray.count == 0;
        }

        // Fallback: SectionRenderer.description
        NSString *sectionDescription = [sectionRenderer description];
        NSString *sectionPostString = getVideoString(sectionDescription);
        if (sectionPostString) {
        NTYTLog(@"NTYT sectionFallback %@ %@", sectionPostString, sectionRenderer);
            return YES;
        }

        // Section.firstObject ElementRenderer
        // VideoならSectionごと削除
        YTIItemSectionSupportedRenderers *firstObject = [contentsArray firstObject];
        YTIElementRenderer *elementRenderer = firstObject.elementRenderer;
        return shouldBlockStandaloneVideo(elementRenderer);
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