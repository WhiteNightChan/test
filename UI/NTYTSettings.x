#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import <YouTubeHeader/YTIIcon.h>
#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>

#import "NTYTRuleListController.h"
#import "../Rule/NTYTRuleManager.h"
#import "../NTYTLogHelper.h"

@class YTSettingsCell;

@interface YTSettingsGroupData (NTYTYouGroupSettings)
+ (NSMutableArray<NSNumber *> *)tweaks;
@end

@interface YTSettingsSectionItemManager (NTYT)
- (void)updateNTYTSectionWithEntry:(id _Nullable)entry;
@end

/*
 * Must match the category already registered by the user's
 * YouGroupSettings fork:
 *
 *     static const NSInteger NoThankYouTube = 'ntyt';
 */
static const NSInteger NTYTSettingsCategory = 'ntyt';

static NSUInteger NTYTCountRulesWithPrefix(NSString *prefix) {
    NTYTRuleManager *manager = [NTYTRuleManager sharedManager];
    NSUInteger count = 0;

    for (NTYTRule *rule in manager.allowRules) {
        if ([rule.sourceSection hasPrefix:prefix]) {
            count++;
        }
    }

    for (NTYTRule *rule in manager.blockRules) {
        if ([rule.sourceSection hasPrefix:prefix]) {
            count++;
        }
    }

    return count;
}

static NSString *NTYTCountDescription(NSString *prefix) {
    NSUInteger count = NTYTCountRulesWithPrefix(prefix);
    return [NSString stringWithFormat:@"%lu rule%@",
                                      (unsigned long)count,
                                      count == 1 ? @"" : @"s"];
}

static void NTYTPushRuleScreen(YTSettingsViewController *settingsVC,
                               NTYTRuleListScope scope) {
    UINavigationController *navigationController = settingsVC.navigationController;
    if (!navigationController) {
        NTYTLog(@"[NTYT][UI] cannot open rule screen: navigationController=nil scope=%ld",
                (long)scope);
        return;
    }

    NTYTRuleListController *controller =
        [[NTYTRuleListController alloc] initWithScope:scope];

    NTYTLog(@"[NTYT][UI] open rule screen scope=%ld", (long)scope);
    [navigationController pushViewController:controller animated:YES];
}

static YTSettingsViewController *NTYTSettingsViewControllerForManager(id manager) {
    id delegate = nil;

    /*
     * Gonerino uses _settingsViewControllerDelegate.
     * YTABConfig uses _dataDelegate on some YouTube generations.
     * Resolve conservatively and never allow an unknown KVC key to crash
     * the Settings screen.
     */
    @try {
        delegate = [manager valueForKey:@"_settingsViewControllerDelegate"];
    } @catch (NSException *exception) {
        (void)exception;
    }

    if (![delegate isKindOfClass:%c(YTSettingsViewController)]) {
        delegate = nil;
        @try {
            delegate = [manager valueForKey:@"_dataDelegate"];
        } @catch (NSException *exception) {
            (void)exception;
        }
    }

    if (![delegate isKindOfClass:%c(YTSettingsViewController)]) {
        return nil;
    }

    return (YTSettingsViewController *)delegate;
}

%hook YTAppSettingsPresentationData

+ (NSArray<NSNumber *> *)settingsCategoryOrder {
    NSArray<NSNumber *> *original = %orig;
    NSMutableArray<NSNumber *> *order = original.mutableCopy ?: [NSMutableArray array];
    NSNumber *category = @(NTYTSettingsCategory);

    if ([order containsObject:category]) {
        return order.copy;
    }

    NSUInteger insertIndex = [order indexOfObject:@(1)];
    if (insertIndex == NSNotFound) {
        [order addObject:category];
    } else {
        [order insertObject:category atIndex:insertIndex + 1];
    }

    return order.copy;
}

%end

/*
 * Grouped/Cairo Settings fallback.
 *
 * If YouGroupSettings is installed, it provides +[YTSettingsGroupData tweaks]
 * and already contains 'ntyt', so its own group ordering is authoritative.
 *
 * If YouGroupSettings is absent, follow YTABConfig's compatibility pattern and
 * add NTYT to group type 1 so grouped Settings can still reach the category.
 */
%hook YTSettingsGroupData

- (NSArray<NSNumber *> *)orderedCategories {
    if (self.type != 1 ||
        class_getClassMethod(objc_getClass("YTSettingsGroupData"), @selector(tweaks))) {
        return %orig;
    }

    NSArray<NSNumber *> *original = %orig;
    NSMutableArray<NSNumber *> *categories =
        original.mutableCopy ?: [NSMutableArray array];
    NSNumber *category = @(NTYTSettingsCategory);

    if (![categories containsObject:category]) {
        [categories insertObject:category atIndex:0];
    }

    return categories.copy;
}

%end

%hook YTSettingsSectionItemManager

%new
- (void)updateNTYTSectionWithEntry:(id)entry {
    (void)entry;

    YTSettingsViewController *delegate =
        NTYTSettingsViewControllerForManager(self);

    if (!delegate) {
        NTYTLog(@"[NTYT][UI] settings delegate unavailable");
        return;
    }

    NSMutableArray<YTSettingsSectionItem *> *items = [NSMutableArray array];

    [items addObject:[%c(YTSettingsSectionItem)
        itemWithTitle:@"General"
        titleDescription:NTYTCountDescription(@"general.")
        accessibilityIdentifier:@"nothankyoutube.general"
        detailTextBlock:nil
        selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger arg1) {
            (void)cell;
            (void)arg1;
            NTYTPushRuleScreen(delegate, NTYTRuleListScopeGeneral);
            return YES;
        }]];

    [items addObject:[%c(YTSettingsSectionItem)
        itemWithTitle:@"Videos"
        titleDescription:NTYTCountDescription(@"videos.")
        accessibilityIdentifier:@"nothankyoutube.videos"
        detailTextBlock:nil
        selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger arg1) {
            (void)cell;
            (void)arg1;
            NTYTPushRuleScreen(delegate, NTYTRuleListScopeVideos);
            return YES;
        }]];

    [items addObject:[%c(YTSettingsSectionItem)
        itemWithTitle:@"Channels"
        titleDescription:NTYTCountDescription(@"channels.")
        accessibilityIdentifier:@"nothankyoutube.channels"
        detailTextBlock:nil
        selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger arg1) {
            (void)cell;
            (void)arg1;
            NTYTPushRuleScreen(delegate, NTYTRuleListScopeChannels);
            return YES;
        }]];

    [items addObject:[%c(YTSettingsSectionItem)
        itemWithTitle:@"Custom Rules"
        titleDescription:NTYTCountDescription(@"custom.")
        accessibilityIdentifier:@"nothankyoutube.custom"
        detailTextBlock:nil
        selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger arg1) {
            (void)cell;
            (void)arg1;
            NTYTPushRuleScreen(delegate, NTYTRuleListScopeCustomRules);
            return YES;
        }]];

    if ([delegate respondsToSelector:
            @selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        /*
         * nil is intentional. When YouGroupSettings owns this category it
         * supplies the standard YT_SETTINGS gear icon for supported tweaks.
         * YTLite also passes nil on the modern setSectionItems variant.
         */
        [delegate setSectionItems:items
                      forCategory:NTYTSettingsCategory
                            title:@"NoThankYouTube"
                             icon:nil
                 titleDescription:@"Video filtering rules"
                     headerHidden:NO];

        NTYTLog(@"[NTYT][UI] settings section registered category=%ld variant=icon rows=%lu",
                (long)NTYTSettingsCategory,
                (unsigned long)items.count);
    } else if ([delegate respondsToSelector:
                   @selector(setSectionItems:forCategory:title:titleDescription:headerHidden:)]) {
        [delegate setSectionItems:items
                      forCategory:NTYTSettingsCategory
                            title:@"NoThankYouTube"
                 titleDescription:@"Video filtering rules"
                     headerHidden:NO];

        NTYTLog(@"[NTYT][UI] settings section registered category=%ld variant=legacy rows=%lu",
                (long)NTYTSettingsCategory,
                (unsigned long)items.count);
    } else {
        NTYTLog(@"[NTYT][UI] expected setSectionItems selector unavailable");
    }
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == NTYTSettingsCategory) {
        [self updateNTYTSectionWithEntry:entry];
        return;
    }

    %orig;
}

%end

/*
 * Deliberately no YTSettingsViewController -loadWithModel: hook and no
 * -viewWillAppear: hook. Section construction is owned by
 * YTSettingsSectionItemManager, matching the stable YTLite/YTABConfig pattern.
 */

%ctor {
    %init;
}
