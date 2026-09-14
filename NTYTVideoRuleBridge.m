#import "NTYTVideoRuleBridge.h"

#import "NTYTVideoIdentifier.h"

#import "Rule/NTYTRule.h"
#import "Rule/NTYTRuleEvaluationContext.h"
#import "Rule/NTYTRuleEvaluationOptions.h"
#import "Rule/NTYTRuleEvaluator.h"
#import "Rule/NTYTRuleParser.h"

#import "NTYTLogHelper.h"

static NSArray<NTYTRule *> *NTYTPhase4AllowRules(void) {
    static NSArray<NTYTRule *> *rules;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        rules = @[];
    });

    return rules;
}

static NSArray<NTYTRule *> *NTYTPhase4BlockRules(void) {
    static NSArray<NTYTRule *> *rules;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        NSError *error = nil;

        /*
         * Phase 4 runtime smoke test:
         *
         * The same temporary "自作PC" behavior is now compiled by the
         * Advanced Parser instead of being hand-written NSDictionary.
         *
         * Phase 5 will replace this fixed source with persisted rules.
         */
        NTYTRuleParserResult *result =
            [NTYTRuleParser
                parseSource:@"/自作pc/i"
                sourceSection:@"general.block"
                baseField:NTYTFieldGeneralText
                identifierPrefix:@"phase4.general.block"
                error:&error];

        if (!result) {
            NTYTLog(
                @"[NTYT][RuleBridge] Phase 4 parser failed: %@",
                error
            );

            // Fail safe: parser failure must never broaden blocking.
            rules = @[];
            return;
        }

        rules = result.rules;
    });

    return rules;
}

static NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *
NTYTPhase4DefaultOptions(void) {
    static NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *options;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        // General:
        //   Case sensitive = OFF
        //   Exact match    = OFF
        //   Word boundary  = OFF
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
            allowRules:NTYTPhase4AllowRules()
            blockRules:NTYTPhase4BlockRules()
            defaultOptionsBySection:NTYTPhase4DefaultOptions()];

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
