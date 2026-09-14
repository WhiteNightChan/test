#import "NTYTRuleParserSelfTest.h"

#import "NTYTCondition.h"
#import "NTYTRule.h"
#import "NTYTRuleEvaluationContext.h"
#import "NTYTRuleEvaluationOptions.h"
#import "NTYTRuleEvaluator.h"
#import "NTYTRuleParser.h"

#import "../NTYTLogHelper.h"

static BOOL NTYTParserAssert(
    BOOL condition,
    NSString *message
) {
    if (!condition) {
        NTYTLog(
            @"[NTYT][ParserSelfTest] FAIL: %@",
            message
        );
        return NO;
    }

    return YES;
}

static NTYTRuleParserResult *NTYTParseTestSource(
    NSString *source,
    NTYTField baseField,
    NSError **error
) {
    return [NTYTRuleParser
        parseSource:source
        sourceSection:@"general.block"
        baseField:baseField
        identifierPrefix:@"parser-test"
        error:error];
}

static NTYTCondition *NTYTFirstConditionForField(
    NTYTRule *rule,
    NTYTField field
) {
    for (NTYTCondition *condition in rule.predicates) {
        if (condition.field == field) {
            return condition;
        }
    }

    return nil;
}

BOOL NTYTRunRuleParserSelfTests(void) {
    NSError *error = nil;

    // 1. Basic literal.
    NTYTRuleParserResult *basic =
        NTYTParseTestSource(
            @"自作PC",
            NTYTFieldGeneralText,
            &error
        );

    if (!NTYTParserAssert(
            basic != nil && error == nil,
            @"basic literal should parse"
        ) ||
        !NTYTParserAssert(
            basic.rules.count == 1,
            @"basic literal should create one rule"
        )) {
        return NO;
    }

    NTYTCondition *basicCondition =
        basic.rules.firstObject.predicates.firstObject;

    if (!NTYTParserAssert(
            basicCondition.field == NTYTFieldGeneralText &&
            basicCondition.matcher == NTYTMatcherContains &&
            [(NSString *)basicCondition.value
                isEqualToString:@"自作PC"] &&
            !basicCondition.negated,
            @"basic literal predicate mismatch"
        )) {
        return NO;
    }

    // 2. Negative keyword.
    error = nil;
    NTYTRuleParserResult *negative =
        NTYTParseTestSource(
            @"!banana",
            NTYTFieldVideoText,
            &error
        );

    if (!NTYTParserAssert(
            negative != nil && error == nil &&
            negative.rules.firstObject
                .predicates.firstObject.negated,
            @"negative keyword should set negated"
        )) {
        return NO;
    }

    // 3. Regex + flags.
    error = nil;
    NTYTRuleParserResult *regex =
        NTYTParseTestSource(
            @"/aaa+/im",
            NTYTFieldVideoText,
            &error
        );

    NTYTCondition *regexCondition =
        regex.rules.firstObject.predicates.firstObject;

    if (!NTYTParserAssert(
            regex != nil && error == nil &&
            regexCondition.matcher == NTYTMatcherRegex &&
            [(NSString *)regexCondition.value
                isEqualToString:@"aaa+"] &&
            [regexCondition.regexFlags
                isEqualToString:@"im"],
            @"regex pattern / flags should be preserved"
        )) {
        return NO;
    }

    // 4. Escaped slash stays in the regex body.
    error = nil;
    NTYTRuleParserResult *escapedSlash =
        NTYTParseTestSource(
            @"/foo\\/bar/i",
            NTYTFieldVideoText,
            &error
        );

    if (!NTYTParserAssert(
            escapedSlash != nil && error == nil &&
            [(NSString *)escapedSlash.rules.firstObject
                .predicates.firstObject.value
                isEqualToString:@"foo\\/bar"],
            @"escaped slash should stay in regex body"
        )) {
        return NO;
    }

    // 5. $& becomes predicates inside one ALL rule.
    error = nil;
    NTYTRuleParserResult *andRule =
        NTYTParseTestSource(
            @"chocolate $& cake",
            NTYTFieldVideoText,
            &error
        );

    if (!NTYTParserAssert(
            andRule != nil && error == nil &&
            andRule.rules.count == 1 &&
            andRule.rules.firstObject.predicates.count == 2,
            @"$& should create two predicates in one rule"
        )) {
        return NO;
    }

    // 6. Top-level comma separates rules, escaped comma does not.
    error = nil;
    NTYTRuleParserResult *escapedComma =
        NTYTParseTestSource(
            @"apple\\, orange, watermelon",
            NTYTFieldVideoText,
            &error
        );

    if (!NTYTParserAssert(
            escapedComma != nil && error == nil &&
            escapedComma.rules.count == 2 &&
            [(NSString *)escapedComma.rules[0]
                .predicates.firstObject.value
                isEqualToString:@"apple, orange"],
            @"escaped comma should remain in keyword"
        )) {
        return NO;
    }

    // 7. ${cs} / ${!cs} only override the following base predicate.
    error = nil;
    NTYTRuleParserResult *caseOn =
        NTYTParseTestSource(
            @"${cs} banana",
            NTYTFieldVideoText,
            &error
        );

    if (!NTYTParserAssert(
            caseOn != nil && error == nil &&
            caseOn.rules.firstObject
                .predicates.firstObject
                .caseSensitiveOverride ==
                    NTYTOptionOverrideForceOn,
            @"${cs} should force case sensitive on"
        )) {
        return NO;
    }

    error = nil;
    NTYTRuleParserResult *caseOff =
        NTYTParseTestSource(
            @"${!cs} banana",
            NTYTFieldVideoText,
            &error
        );

    if (!NTYTParserAssert(
            caseOff != nil && error == nil &&
            caseOff.rules.firstObject
                .predicates.firstObject
                .caseSensitiveOverride ==
                    NTYTOptionOverrideForceOff,
            @"${!cs} should force case sensitive off"
        )) {
        return NO;
    }

    // 8. Channel modifier is an AND predicate; literal channel identity is exact.
    error = nil;
    NTYTRuleParserResult *channel =
        NTYTParseTestSource(
            @"${ch: badChannel01} banana",
            NTYTFieldVideoText,
            &error
        );

    NTYTCondition *channelCondition =
        NTYTFirstConditionForField(
            channel.rules.firstObject,
            NTYTFieldChannelIdentity
        );

    if (!NTYTParserAssert(
            channel != nil && error == nil &&
            channel.rules.firstObject.predicates.count == 2 &&
            channelCondition != nil &&
            channelCondition.matcher == NTYTMatcherExact &&
            [(NSString *)channelCondition.value
                isEqualToString:@"badChannel01"],
            @"channel modifier should compile as exact identity predicate"
        )) {
        return NO;
    }

    // 9. Modifier value regex + negative modifier.
    error = nil;
    NTYTRuleParserResult *negativeContentRegex =
        NTYTParseTestSource(
            @"${!ctn: /^(?!.*Elfilis).*$/i } /^.*$/",
            NTYTFieldGeneralText,
            &error
        );

    NTYTCondition *contentCondition =
        NTYTFirstConditionForField(
            negativeContentRegex.rules.firstObject,
            NTYTFieldContentText
        );

    if (!NTYTParserAssert(
            negativeContentRegex != nil &&
            error == nil &&
            contentCondition != nil &&
            contentCondition.matcher == NTYTMatcherRegex &&
            contentCondition.negated &&
            [(NSString *)contentCondition.value
                isEqualToString:@"^(?!.*Elfilis).*$"] &&
            [contentCondition.regexFlags
                isEqualToString:@"i"],
            @"negative modifier regex should preserve body / flags"
        )) {
        return NO;
    }

    // 10. ${video: VALUE} has frozen NTYT semantics:
    // is_video == YES AND video_text matches VALUE.
    error = nil;
    NTYTRuleParserResult *videoValue =
        NTYTParseTestSource(
            @"${video: gameplay} /^.*$/",
            NTYTFieldGeneralText,
            &error
        );

    if (!NTYTParserAssert(
            videoValue != nil && error == nil &&
            NTYTFirstConditionForField(
                videoValue.rules.firstObject,
                NTYTFieldIsVideo
            ) != nil &&
            NTYTFirstConditionForField(
                videoValue.rules.firstObject,
                NTYTFieldVideoText
            ) != nil,
            @"${video: VALUE} should add is_video and video_text"
        )) {
        return NO;
    }

    // 11. Current future-provider modifiers compile, but do not disappear.
    // description is a real field whose provider is currently nil.
    error = nil;
    NTYTRuleParserResult *description =
        NTYTParseTestSource(
            @"${desc: /Auto-generated by YouTube\\./i } /^.*$/",
            NTYTFieldGeneralText,
            &error
        );

    if (!NTYTParserAssert(
            description != nil && error == nil &&
            NTYTFirstConditionForField(
                description.rules.firstObject,
                NTYTFieldDescription
            ) != nil,
            @"description modifier should compile to description field"
        )) {
        return NO;
    }

    // 12. A documented modifier without a provider becomes an explicit
    // NTYTFieldUnsupported predicate, forcing UNKNOWN instead of partial match.
    error = nil;
    NTYTRuleParserResult *unsupported =
        NTYTParseTestSource(
            @"${premiere} foo",
            NTYTFieldVideoText,
            &error
        );

    NTYTCondition *unsupportedCondition =
        NTYTFirstConditionForField(
            unsupported.rules.firstObject,
            NTYTFieldUnsupported
        );

    if (!NTYTParserAssert(
            unsupported != nil && error == nil &&
            unsupported.unsupportedModifiers.count == 1 &&
            [unsupported.unsupportedModifiers.firstObject
                isEqualToString:@"premiere"] &&
            unsupportedCondition != nil,
            @"unsupported modifier must compile to explicit UNKNOWN predicate"
        )) {
        return NO;
    }

    NTYTRuleEvaluationContext *context =
        [NTYTRuleEvaluationContext
            videoContextWithVideoID:@"ABCDEFGHIJK"
            title:@"foo"
            channelID:@"UC_TEST"
            channelName:@"Test"
            handle:@"/@test"
            viewCountText:@"1万回視聴"
            isShort:@NO];

    NTYTMatchResult unsupportedResult =
        [NTYTRuleEvaluator
            evaluateRule:unsupported.rules.firstObject
            context:context
            defaultOptions:
                [NTYTRuleEvaluationOptions defaultOptions]
            error:NULL];

    if (!NTYTParserAssert(
            unsupportedResult == NTYTMatchResultUnknown,
            @"unsupported modifier must evaluate UNKNOWN"
        )) {
        return NO;
    }

    // 13. Preserve advanced regex constructs at parser level.
    error = nil;
    NTYTRuleParserResult *advancedRegex =
        NTYTParseTestSource(
            @"/(?<!NO)(?-i:UC[-\\w]{22})/im",
            NTYTFieldGeneralText,
            &error
        );

    if (!NTYTParserAssert(
            advancedRegex != nil && error == nil &&
            [(NSString *)advancedRegex.rules.firstObject
                .predicates.firstObject.value
                isEqualToString:
                    @"(?<!NO)(?-i:UC[-\\w]{22})"],
            @"parser must not rewrite advanced regex body"
        )) {
        return NO;
    }

    // 14. Invalid syntax stays distinct from unsupported syntax.
    error = nil;
    NTYTRuleParserResult *badRegex =
        NTYTParseTestSource(
            @"/unterminated",
            NTYTFieldGeneralText,
            &error
        );

    if (!NTYTParserAssert(
            badRegex == nil &&
            error != nil &&
            [error.domain
                isEqualToString:
                    NTYTRuleParserErrorDomain],
            @"unterminated regex should be parser error"
        )) {
        return NO;
    }

    error = nil;
    NTYTRuleParserResult *badModifier =
        NTYTParseTestSource(
            @"${ch: foo banana",
            NTYTFieldGeneralText,
            &error
        );

    if (!NTYTParserAssert(
            badModifier == nil && error != nil,
            @"unterminated modifier should be parser error"
        )) {
        return NO;
    }

    error = nil;
    NTYTRuleParserResult *badAnd =
        NTYTParseTestSource(
            @"foo $&",
            NTYTFieldGeneralText,
            &error
        );

    if (!NTYTParserAssert(
            badAnd == nil && error != nil,
            @"empty $& operand should be parser error"
        )) {
        return NO;
    }


    // 15. Negative regex remains a regex predicate with negated = YES.
    error = nil;
    NTYTRuleParserResult *negativeRegex =
        NTYTParseTestSource(
            @"!/^a/i",
            NTYTFieldVideoText,
            &error
        );

    if (!NTYTParserAssert(
            negativeRegex != nil && error == nil &&
            negativeRegex.rules.firstObject
                .predicates.firstObject.matcher ==
                    NTYTMatcherRegex &&
            negativeRegex.rules.firstObject
                .predicates.firstObject.negated,
            @"negative regex should preserve regex matcher and negate it"
        )) {
        return NO;
    }

    // 16. Regex commas are not top-level separators.
    error = nil;
    NTYTRuleParserResult *regexComma =
        NTYTParseTestSource(
            @"/foo,bar/i, baz",
            NTYTFieldVideoText,
            &error
        );

    if (!NTYTParserAssert(
            regexComma != nil && error == nil &&
            regexComma.rules.count == 2 &&
            [(NSString *)regexComma.rules.firstObject
                .predicates.firstObject.value
                isEqualToString:@"foo,bar"],
            @"comma inside regex must not split rules"
        )) {
        return NO;
    }

    // 17. Regex inside a modifier can contain commas and braces.
    error = nil;
    NTYTRuleParserResult *modifierComplexRegex =
        NTYTParseTestSource(
            @"${ctn: /a{2},b/i } /^.*$/",
            NTYTFieldGeneralText,
            &error
        );

    NTYTCondition *modifierComplexCondition =
        NTYTFirstConditionForField(
            modifierComplexRegex.rules.firstObject,
            NTYTFieldContentText
        );

    if (!NTYTParserAssert(
            modifierComplexRegex != nil &&
            error == nil &&
            modifierComplexCondition != nil &&
            [(NSString *)modifierComplexCondition.value
                isEqualToString:@"a{2},b"],
            @"modifier regex must keep comma / braces inside regex"
        )) {
        return NO;
    }

    // 18. Exact / word-boundary modifiers compile as base predicate overrides.
    error = nil;
    NTYTRuleParserResult *literalOptions =
        NTYTParseTestSource(
            @"${em} ${wb} banana",
            NTYTFieldVideoText,
            &error
        );

    NTYTCondition *literalOptionsCondition =
        literalOptions.rules.firstObject
            .predicates.firstObject;

    if (!NTYTParserAssert(
            literalOptions != nil && error == nil &&
            literalOptionsCondition.exactMatchOverride ==
                NTYTOptionOverrideForceOn &&
            literalOptionsCondition.wordBoundaryOverride ==
                NTYTOptionOverrideForceOn,
            @"${em}/${wb} should override base literal options"
        )) {
        return NO;
    }

    // 19. Real corpus shape: negative short + description regex + advanced
    // base regex. Parser only preserves syntax; evaluator/provider support is
    // intentionally separate.
    error = nil;
    NTYTRuleParserResult *corpusRule =
        NTYTParseTestSource(
            @"${!short} "
             "${desc: /Auto-generated by YouTube\\./i } "
             @"/^(?=.*(?:batta|THE ?DU|SPYAIR|GANASIA|YOASOBI)).*$/i",
            NTYTFieldGeneralText,
            &error
        );

    if (!NTYTParserAssert(
            corpusRule != nil && error == nil &&
            NTYTFirstConditionForField(
                corpusRule.rules.firstObject,
                NTYTFieldIsShort
            ) != nil &&
            NTYTFirstConditionForField(
                corpusRule.rules.firstObject,
                NTYTFieldDescription
            ) != nil &&
            corpusRule.rules.firstObject
                .predicates.firstObject.matcher ==
                    NTYTMatcherRegex,
            @"real corpus rule shape should parse"
        )) {
        return NO;
    }

    // 20. Unknown modifier names are accepted as unsupported rather than
    // silently discarded or treated as malformed syntax.
    error = nil;
    NTYTRuleParserResult *unknownModifier =
        NTYTParseTestSource(
            @"${futurething: abc} foo",
            NTYTFieldVideoText,
            &error
        );

    if (!NTYTParserAssert(
            unknownModifier != nil && error == nil &&
            [unknownModifier.unsupportedModifiers.firstObject
                isEqualToString:@"futurething"] &&
            NTYTFirstConditionForField(
                unknownModifier.rules.firstObject,
                NTYTFieldUnsupported
            ) != nil,
            @"unknown modifier should compile fail-safe as unsupported"
        )) {
        return NO;
    }

    // 21. The negative compound ${!video: VALUE} semantics were never frozen.
    // Accept the syntax but force UNKNOWN instead of inventing boolean logic.
    error = nil;
    NTYTRuleParserResult *negativeVideoValue =
        NTYTParseTestSource(
            @"${!video: foo} /^.*$/",
            NTYTFieldGeneralText,
            &error
        );

    if (!NTYTParserAssert(
            negativeVideoValue != nil && error == nil &&
            [negativeVideoValue.unsupportedModifiers
                containsObject:@"!video:value"] &&
            NTYTFirstConditionForField(
                negativeVideoValue.rules.firstObject,
                NTYTFieldUnsupported
            ) != nil,
            @"negative video:value should be explicit UNKNOWN"
        )) {
        return NO;
    }

    NTYTLog(@"[NTYT][ParserSelfTest] PASS");
    return YES;
}
