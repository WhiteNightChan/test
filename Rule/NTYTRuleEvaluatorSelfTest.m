#import "NTYTRuleEvaluatorSelfTest.h"

#import "NTYTRule.h"
#import "NTYTRuleEvaluator.h"

static NTYTRule *NTYTRuleFromDictionaryOrNil(
    NSDictionary *dictionary
) {
    NSError *error = nil;
    NTYTRule *rule =
        [NTYTRule ruleFromDictionary:dictionary
                               error:&error];

    if (!rule) {
        NSLog(@"[NTYT][SelfTest] Rule parse failed: %@", error);
    }

    return rule;
}

BOOL NTYTRunRuleEvaluatorSelfTests(void) {
    NTYTRuleEvaluationContext *context =
        [[NTYTRuleEvaluationContext alloc]
            initWithVideoID:@"ABCDEFGHIJK"
            title:@"BBBB gameplay"
            channelID:@"UC_TEST"
            channelName:@"AAAA"
            handle:@"/@aaaa"
            viewCountText:@"4,555回視聴"
            approxViewCount:@4555
            isVideo:@YES
            isShort:@NO
            videoDescription:nil
            tags:nil
            isLive:nil
            isMember:nil];

    NSDictionary *defaults = @{
        @"custom": [NTYTRuleEvaluationOptions
            optionsWithCaseSensitive:NO
            exactMatch:NO
            wordBoundary:NO],
        @"channels.allow": [NTYTRuleEvaluationOptions
            optionsWithCaseSensitive:NO
            exactMatch:YES
            wordBoundary:NO],
    };

    NTYTRule *andRule =
        NTYTRuleFromDictionaryOrNil(@{
            @"id": @"phase2.and",
            @"enabled": @YES,
            @"sourceSection": @"custom",
            @"baseField": @"channel_identity",
            @"combinator": @"all",
            @"predicates": @[
                @{
                    @"field": @"channel_identity",
                    @"matcher": @"exact",
                    @"value": @"AAAA",
                    @"negated": @NO,
                },
                @{
                    @"field": @"video_text",
                    @"matcher": @"contains",
                    @"value": @"BBBB",
                    @"negated": @NO,
                },
            ],
        });

    if (!andRule) {
        return NO;
    }

    if ([NTYTRuleEvaluator evaluateRule:andRule
                                context:context
                         defaultOptions:defaults[@"custom"]
                                  error:nil] != NTYTMatchResultMatch) {
        NSLog(@"[NTYT][SelfTest] AND rule failed");
        return NO;
    }

    NTYTRule *regexRule =
        NTYTRuleFromDictionaryOrNil(@{
            @"id": @"phase2.regex",
            @"enabled": @YES,
            @"sourceSection": @"custom",
            @"baseField": @"video_text",
            @"predicates": @[
                @{
                    @"field": @"video_text",
                    @"matcher": @"regex",
                    @"value": @"^bbbb",
                    @"regexFlags": @"i",
                    @"negated": @NO,
                },
            ],
        });

    if (!regexRule) {
        return NO;
    }

    if ([NTYTRuleEvaluator evaluateRule:regexRule
                                context:context
                         defaultOptions:defaults[@"custom"]
                                  error:nil] != NTYTMatchResultMatch) {
        NSLog(@"[NTYT][SelfTest] Regex rule failed");
        return NO;
    }

    NTYTRule *unknownRule =
        NTYTRuleFromDictionaryOrNil(@{
            @"id": @"phase2.unknown",
            @"enabled": @YES,
            @"sourceSection": @"custom",
            @"baseField": @"description",
            @"predicates": @[
                @{
                    @"field": @"description",
                    @"matcher": @"contains",
                    @"value": @"Auto-generated",
                    @"negated": @NO,
                },
            ],
        });

    if (!unknownRule) {
        return NO;
    }

    if ([NTYTRuleEvaluator evaluateRule:unknownRule
                                context:context
                         defaultOptions:defaults[@"custom"]
                                  error:nil] != NTYTMatchResultUnknown) {
        NSLog(@"[NTYT][SelfTest] UNKNOWN rule failed");
        return NO;
    }

    NTYTRule *blockRule =
        NTYTRuleFromDictionaryOrNil(@{
            @"id": @"phase2.block",
            @"enabled": @YES,
            @"sourceSection": @"custom",
            @"baseField": @"video_text",
            @"predicates": @[
                @{
                    @"field": @"video_text",
                    @"matcher": @"contains",
                    @"value": @"BBBB",
                    @"negated": @NO,
                },
            ],
        });

    NTYTRule *allowRule =
        NTYTRuleFromDictionaryOrNil(@{
            @"id": @"phase2.allow",
            @"enabled": @YES,
            @"sourceSection": @"channels.allow",
            @"baseField": @"channel_identity",
            @"predicates": @[
                @{
                    @"field": @"channel_identity",
                    @"matcher": @"contains",
                    @"value": @"AAAA",
                    @"negated": @NO,
                },
            ],
        });

    if (!blockRule || !allowRule) {
        return NO;
    }

    if ([NTYTRuleEvaluator shouldBlockContext:context
                                   allowRules:@[]
                                   blockRules:@[blockRule]
                      defaultOptionsBySection:defaults] != YES) {
        NSLog(@"[NTYT][SelfTest] Block rule failed");
        return NO;
    }

    if ([NTYTRuleEvaluator shouldBlockContext:context
                                   allowRules:@[allowRule]
                                   blockRules:@[blockRule]
                      defaultOptionsBySection:defaults] != NO) {
        NSLog(@"[NTYT][SelfTest] Allow precedence failed");
        return NO;
    }

    NTYTRule *negatedRule =
        NTYTRuleFromDictionaryOrNil(@{
            @"id": @"phase2.negated",
            @"enabled": @YES,
            @"sourceSection": @"custom",
            @"baseField": @"video_text",
            @"predicates": @[
                @{
                    @"field": @"video_text",
                    @"matcher": @"contains",
                    @"value": @"ASMR",
                    @"negated": @YES,
                },
            ],
        });

    if (!negatedRule) {
        return NO;
    }

    if ([NTYTRuleEvaluator evaluateRule:negatedRule
                                context:context
                         defaultOptions:defaults[@"custom"]
                                  error:nil] != NTYTMatchResultMatch) {
        NSLog(@"[NTYT][SelfTest] Negation failed");
        return NO;
    }

    NTYTRule *viewRule =
        NTYTRuleFromDictionaryOrNil(@{
            @"id": @"phase2.view",
            @"enabled": @YES,
            @"sourceSection": @"custom",
            @"baseField": @"channel_identity",
            @"predicates": @[
                @{
                    @"field": @"channel_identity",
                    @"matcher": @"exact",
                    @"value": @"AAAA",
                    @"negated": @NO,
                },
                @{
                    @"field": @"view_count",
                    @"matcher": @"less_than_or_equal",
                    @"value": @10000,
                    @"negated": @NO,
                },
            ],
        });

    if (!viewRule) {
        return NO;
    }

    if ([NTYTRuleEvaluator evaluateRule:viewRule
                                context:context
                         defaultOptions:defaults[@"custom"]
                                  error:nil] != NTYTMatchResultMatch) {
        NSLog(@"[NTYT][SelfTest] Numeric view rule failed");
        return NO;
    }

    NSLog(@"[NTYT][SelfTest] Phase 2 evaluator tests passed");
    return YES;
}
