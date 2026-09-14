#import "NTYTVideoRuleBridge.h"

#import "NTYTVideoIdentifier.h"

#import "Rule/NTYTRuleEvaluationContext.h"
#import "Rule/NTYTRuleEvaluator.h"
#import "Rule/NTYTRuleManager.h"

#import "NTYTLogHelper.h"

BOOL NTYTShouldBlockStandaloneVideoMetadata(
    NTYTVideoMetadata *metadata
) {
    if (!metadata) {
        return NO;
    }

    NTYTRuleManager *ruleManager = [NTYTRuleManager sharedManager];

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
            allowRules:ruleManager.effectiveAllowRules
            blockRules:ruleManager.effectiveBlockRules
            defaultOptionsBySection:ruleManager.defaultOptionsBySection];

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
