#import "NTYTVideoRuleBridge.h"

#import "NTYTVideoIdentifier.h"

#import "Rule/NTYTRule.h"
#import "Rule/NTYTRuleEvaluationContext.h"
#import "Rule/NTYTRuleEvaluationOptions.h"
#import "Rule/NTYTRuleEvaluator.h"

#import "NTYTLogHelper.h"

static NSArray<NTYTRule *> *NTYTPhase3AllowRules(void) {
    static NSArray<NTYTRule *> *rules;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        // Phase 3 intentionally starts with no allow rules.
        //
        // The purpose of this phase is to prove:
        //
        // YTIElementRenderer
        //   -> NTYTVideoMetadata
        //   -> NTYTRuleEvaluationContext
        //   -> NTYTRuleEvaluator
        //   -> PASS / BLOCK
        //
        // Whitelist semantics are already implemented in the evaluator and
        // will be exercised once rules come from the parser/manager.
        rules = @[];
    });

    return rules;
}

static NSArray<NTYTRule *> *NTYTPhase3BlockRules(void) {
    static NSArray<NTYTRule *> *rules;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        NSError *error = nil;

        // Temporary hand-written rule used only for Phase 3 integration.
        //
        // This deliberately reproduces the old temporary behavior:
        // case-insensitive partial match for "自作PC" over General fields.
        //
        // General fields:
        //   video_id
        //   title
        //   channel_id
        //   channel_name
        //   handle
        //
        // view_count is NOT included.
        NSDictionary *dictionary = @{
            @"id": @"phase3.general.block.jisaku-pc",
            @"enabled": @YES,
            @"sourceSection": @"general.block",
            @"baseField": @"general_text",
            @"combinator": @"all",
            @"predicates": @[
                @{
                    @"field": @"general_text",
                    @"matcher": @"contains",
                    @"value": @"自作PC",
                    @"negated": @NO,
                    @"options": @{
                        @"caseSensitive": @"inherit",
                        @"exactMatch": @"inherit",
                        @"wordBoundary": @"inherit",
                    },
                },
            ],
        };

        NTYTRule *rule =
            [NTYTRule ruleFromDictionary:dictionary
                                   error:&error];

        if (!rule) {
            NTYTLog(@"[NTYT][RuleBridge] Failed to build Phase 3 rule: %@",
                  error);
            rules = @[];
            return;
        }

        rules = @[rule];
    });

    return rules;
}

static NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *
NTYTPhase3DefaultOptions(void) {
    static NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *options;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        // General:
        //   Case sensitive = OFF
        //   Word boundary  = OFF
        //   Exact match    = OFF
        options = @{
            @"general.block":
                [NTYTRuleEvaluationOptions
                    optionsWithCaseSensitive:NO
                    exactMatch:NO
                    wordBoundary:NO],
        };
    });

    return options;
}

BOOL NTYTShouldBlockStandaloneVideoMetadata(
    NTYTVideoMetadata *metadata
) {
    if (!metadata) {
        return NO;
    }

    NTYTRuleEvaluationContext *context =
        [[NTYTRuleEvaluationContext alloc]
            initWithVideoID:metadata.videoID
            title:metadata.title
            channelID:metadata.channelID
            channelName:metadata.channelName
            handle:metadata.handle
            viewCountText:metadata.viewCountText
            approxViewCount:nil
            isVideo:@YES
            isShort:@NO
            videoDescription:nil
            tags:nil
            isLive:nil
            isMember:nil];

    BOOL shouldBlock =
        [NTYTRuleEvaluator
            shouldBlockContext:context
            allowRules:NTYTPhase3AllowRules()
            blockRules:NTYTPhase3BlockRules()
            defaultOptionsBySection:NTYTPhase3DefaultOptions()];

    if (shouldBlock) {
        NTYTLog(
            @"[NTYT][RuleBridge] BLOCK "
             "video_id=%@ title=%@ channel_id=%@ channel_name=%@ "
             "handle=%@ count_view=%@",
            metadata.videoID ?: @"",
            metadata.title ?: @"",
            metadata.channelID ?: @"",
            metadata.channelName ?: @"",
            metadata.handle ?: @"",
            metadata.viewCountText ?: @""
        );
    }

    return shouldBlock;
}
