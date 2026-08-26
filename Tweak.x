// Tweak.x

#import <Foundation/Foundation.h>
#import <objc/message.h>

static BOOL IsBackstageCommunityEntry(id entry)
{
    if (!entry)
        return NO;

    if (![entry respondsToSelector:@selector(compatibilityOptions)])
        return NO;

    id options = ((id (*)(id, SEL))objc_msgSend)(
        entry,
        @selector(compatibilityOptions)
    );

    if (!options)
        return NO;

    if (![options respondsToSelector:@selector(useBackstageCellControllerOnIos)])
        return NO;

    return ((BOOL (*)(id, SEL))objc_msgSend)(
        options,
        @selector(useBackstageCellControllerOnIos)
    );
}


// ============================================================
// 1. YTInnerTubeCellFactory
//
// use_backstage_cell_controller_on_ios == true の Entry に対して
// CellController の生成そのものを nil にする。
// ============================================================

%hook YTInnerTubeCellFactory

- (id)cellControllerForEntry:(id)entry
            parentResponder:(id)parentResponder
{
    if (IsBackstageCommunityEntry(entry)) {
        return nil;
    }

    return %orig;
}

%end


// ============================================================
// 2. YTSectionController
//
// Factory が nil を返した後に作られる
// YTCellController フォールバックも nil にする。
// ============================================================

%hook YTSectionController

- (id)createCellControllerForEntry:(id)entry
{
    if (IsBackstageCommunityEntry(entry)) {
        return nil;
    }

    return %orig;
}

%end