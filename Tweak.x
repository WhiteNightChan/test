#import <Foundation/Foundation.h>
#import <objc/message.h>

static id CallObject(id obj, SEL sel) {
    if (!obj || ![obj respondsToSelector:sel])
        return nil;

    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}

static BOOL CallBOOL(id obj, SEL sel) {
    if (!obj || ![obj respondsToSelector:sel])
        return NO;

    return ((BOOL (*)(id, SEL))objc_msgSend)(obj, sel);
}


/*
 * ---------------------------------------------------------
 * Community Post 判定
 * ---------------------------------------------------------
 */

static BOOL IsCommunityPostRenderer(id renderer) {
    if (!renderer)
        return NO;

    static Class rendererClass = Nil;

    if (!rendererClass)
        rendererClass = NSClassFromString(@"YTIElementRenderer");

    if (rendererClass &&
        ![renderer isKindOfClass:rendererClass]) {
        return NO;
    }

    id compatibilityOptions =
        CallObject(
            renderer,
            @selector(compatibilityOptions)
        );

    if (!compatibilityOptions)
        return NO;

    return CallBOOL(
        compatibilityOptions,
        @selector(useBackstageCellControllerOnIos)
    );
}


static BOOL IsCommunityPostDescription(NSString *description) {
    if (!description)
        return NO;

    /*
     * 動画プレーヤー内の投稿を削除する際の邪魔になっているため除外。
     *
     * if ([description containsString:@"FEpost_home"])
     *     return NO;
     */

    if ([description containsString:@"post_base_wrapper.eml"])
        return YES;

    if ([description containsString:@"post_base_wrapper_slim.eml"])
        return YES;

    if ([description containsString:@"image_post_root.eml"])
        return YES;

    if ([description containsString:@"images_post_root.eml"])
        return YES;

    if ([description containsString:@"images_post_root_slim.eml"])
        return YES;

    if ([description containsString:@"images_post_responsive_root.eml"])
        return YES;

    if ([description containsString:@"text_post_root.eml"])
        return YES;

    if ([description containsString:@"text_post_root_slim.eml"])
        return YES;

    if ([description containsString:@"videos_post_root.eml"])
        return YES;

    if ([description containsString:@"videos_post_responsive_root.eml"])
        return YES;

    return NO;
}


static BOOL IsCommunityPostRendererWithFallback(id renderer) {
    if (!renderer)
        return NO;

    /*
     * 新条件を優先。
     */
    if (IsCommunityPostRenderer(renderer))
        return YES;

    /*
     * 従来の EML description 判定。
     */
    id description =
        CallObject(
            renderer,
            @selector(description)
        );

    return IsCommunityPostDescription(description);
}


/*
 * YTIShelfRenderer の itemsArray 内の要素用。
 */
static BOOL IsCommunityPostItem(id item) {
    if (!item)
        return NO;

    if (IsCommunityPostRenderer(item))
        return YES;

    id description =
        CallObject(
            item,
            @selector(description)
        );

    return IsCommunityPostDescription(description);
}


/*
 * ---------------------------------------------------------
 * CollectionView系
 *
 * YTInnerTubeCollectionViewController
 *     -> addSectionsFromArray:
 *
 * Section / Shelf 内の Community Post を除去。
 * ---------------------------------------------------------
 */

static NSArray *FilterCommunityPosts(NSArray *sections) {
    if (!sections)
        return nil;

    NSMutableArray *mutableSections = nil;
    NSMutableIndexSet *removeIndexes = nil;

    static Class itemSectionClass = Nil;
    static Class shelfClass = Nil;

    if (!itemSectionClass)
        itemSectionClass =
            NSClassFromString(@"YTIItemSectionRenderer");

    if (!shelfClass)
        shelfClass =
            NSClassFromString(@"YTIShelfRenderer");

    for (NSUInteger i = 0;
         i < sections.count;
         i++) {

        id section = sections[i];

        /*
         * -------------------------------------------------
         * YTIItemSectionRenderer
         *
         * -> contentsArray
         * -> firstObject
         * -> elementRenderer
         * -------------------------------------------------
         */

        if (itemSectionClass &&
            [section isKindOfClass:itemSectionClass]) {

            id contents =
                CallObject(
                    section,
                    @selector(contentsArray)
                );

            id first =
                CallObject(
                    contents,
                    @selector(firstObject)
                );

            id renderer =
                CallObject(
                    first,
                    @selector(elementRenderer)
                );

            if (IsCommunityPostRendererWithFallback(renderer)) {

                if (!mutableSections)
                    mutableSections = [sections mutableCopy];

                if (!removeIndexes)
                    removeIndexes = [NSMutableIndexSet indexSet];

                [removeIndexes addIndex:i];
            }

            continue;
        }


        /*
         * -------------------------------------------------
         * YTIShelfRenderer
         *
         * -> content
         * -> horizontalListRenderer
         * -> itemsArray
         * -------------------------------------------------
         */

        if (shelfClass &&
            [section isKindOfClass:shelfClass]) {

            id content =
                CallObject(
                    section,
                    @selector(content)
                );

            id horizontalListRenderer =
                CallObject(
                    content,
                    @selector(horizontalListRenderer)
                );

            id items =
                CallObject(
                    horizontalListRenderer,
                    @selector(itemsArray)
                );

            if (![items isKindOfClass:[NSMutableArray class]])
                continue;

            NSMutableIndexSet *itemIndexes =
                [NSMutableIndexSet indexSet];

            for (NSUInteger j = 0;
                 j < [items count];
                 j++) {

                id item = items[j];

                if (IsCommunityPostItem(item))
                    [itemIndexes addIndex:j];
            }

            if (itemIndexes.count != 0) {
                [items removeObjectsAtIndexes:itemIndexes];
            }
        }
    }

    if (removeIndexes.count != 0) {
        [mutableSections
            removeObjectsAtIndexes:removeIndexes];

        return mutableSections;
    }

    return sections;
}


/*
 * ---------------------------------------------------------
 * Comment Feed系
 *
 * YTCommentSectionFeedController
 *     -> handleEntries:
 * ---------------------------------------------------------
 */

static NSArray *FilterCommunityPostEntries(NSArray *entries) {
    if (!entries)
        return nil;

    NSMutableArray *filtered = nil;

    for (NSUInteger i = 0;
         i < entries.count;
         i++) {

        id entry = entries[i];

        if (IsCommunityPostRendererWithFallback(entry)) {

            if (!filtered) {
                filtered =
                    [NSMutableArray
                        arrayWithCapacity:entries.count];

                for (NSUInteger j = 0;
                     j < i;
                     j++) {
                    [filtered addObject:entries[j]];
                }
            }

            continue;
        }

        if (filtered)
            [filtered addObject:entry];
    }

    return filtered ?: entries;
}


/*
 * ---------------------------------------------------------
 * Hooks
 * ---------------------------------------------------------
 */

%hook YTInnerTubeCollectionViewController

- (void)addSectionsFromArray:(NSArray *)sections {
    NSArray *filteredSections =
        FilterCommunityPosts(sections);

    %orig(filteredSections ?: sections);
}

%end


%hook YTCommentSectionFeedController

- (void)handleEntries:(NSArray *)entries {

    if (!entries) {
        %orig(nil);
        return;
    }

    NSArray *filtered =
        FilterCommunityPostEntries(entries);

    %orig(filtered);
}

%end