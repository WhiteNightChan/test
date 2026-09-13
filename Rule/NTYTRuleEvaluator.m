#import "NTYTRuleEvaluator.h"

NSErrorDomain const NTYTRuleEvaluatorErrorDomain =
    @"com.nothankyoutubetweak.ruleevaluator";

static NSError *NTYTEvaluatorError(
    NTYTRuleEvaluatorErrorCode code,
    NSString *description
) {
    return [NSError errorWithDomain:NTYTRuleEvaluatorErrorDomain
                               code:code
                           userInfo:@{
                               NSLocalizedDescriptionKey:
                                   description ?: @"Rule evaluation failed."
                           }];
}

static BOOL NTYTEffectiveBool(
    BOOL inheritedValue,
    NTYTOptionOverride override
) {
    switch (override) {
        case NTYTOptionOverrideForceOn:
            return YES;
        case NTYTOptionOverrideForceOff:
            return NO;
        case NTYTOptionOverrideInherit:
        default:
            return inheritedValue;
    }
}

static NSString *NTYTDecodedHandle(NSString *handle) {
    if (![handle isKindOfClass:[NSString class]] || handle.length == 0) {
        return nil;
    }

    NSString *decoded = [handle stringByRemovingPercentEncoding];
    return decoded.length > 0 ? decoded : nil;
}

static NSString *NTYTHandleWithoutLeadingSlash(NSString *handle) {
    if (![handle isKindOfClass:[NSString class]] || handle.length == 0) {
        return nil;
    }

    if ([handle hasPrefix:@"/"] && handle.length > 1) {
        return [handle substringFromIndex:1];
    }

    return handle;
}

static NSArray<NSString *> *NTYTUniqueStrings(
    NSArray *values,
    BOOL *hasUnknown
) {
    NSMutableOrderedSet<NSString *> *set =
        [NSMutableOrderedSet orderedSet];

    BOOL unknown = NO;

    for (id value in values) {
        if (value == [NSNull null] || value == nil) {
            unknown = YES;
            continue;
        }

        if (![value isKindOfClass:[NSString class]]) {
            unknown = YES;
            continue;
        }

        NSString *string = (NSString *)value;
        if (string.length == 0) {
            unknown = YES;
            continue;
        }

        [set addObject:string];
    }

    if (hasUnknown) {
        *hasUnknown = unknown;
    }

    return set.array;
}

static NSArray<NSString *> *NTYTStringCandidatesForField(
    NTYTField field,
    NTYTRuleEvaluationContext *context,
    BOOL *hasUnknown
) {
    BOOL unknown = NO;
    NSArray<NSString *> *result = nil;

    switch (field) {
        case NTYTFieldGeneralText: {
            result = NTYTUniqueStrings(@[
                context.videoID ?: [NSNull null],
                context.title ?: [NSNull null],
                context.channelID ?: [NSNull null],
                context.channelName ?: [NSNull null],
                context.handle ?: [NSNull null],
            ], &unknown);
            break;
        }

        case NTYTFieldContentText:
        case NTYTFieldVideoText: {
            result = NTYTUniqueStrings(@[
                context.title ?: [NSNull null],
            ], &unknown);
            break;
        }

        case NTYTFieldVideoID: {
            result = NTYTUniqueStrings(@[
                context.videoID ?: [NSNull null],
            ], &unknown);
            break;
        }

        case NTYTFieldChannelIdentity: {
            NSMutableArray *values = [NSMutableArray array];

            if (context.channelName) {
                [values addObject:context.channelName];
            } else {
                [values addObject:[NSNull null]];
            }

            if (context.channelID) {
                [values addObject:context.channelID];
            } else {
                [values addObject:[NSNull null]];
            }

            if (context.handle) {
                [values addObject:context.handle];

                NSString *decoded =
                    NTYTDecodedHandle(context.handle);
                if (decoded) {
                    [values addObject:decoded];
                }

                NSString *trimmed =
                    NTYTHandleWithoutLeadingSlash(context.handle);
                if (trimmed) {
                    [values addObject:trimmed];
                }

                NSString *decodedTrimmed =
                    NTYTHandleWithoutLeadingSlash(decoded);
                if (decodedTrimmed) {
                    [values addObject:decodedTrimmed];
                }
            } else {
                [values addObject:[NSNull null]];
            }

            result = NTYTUniqueStrings(values, &unknown);
            break;
        }

        case NTYTFieldDescription: {
            result = NTYTUniqueStrings(@[
                context.videoDescription ?: [NSNull null],
            ], &unknown);
            break;
        }

        case NTYTFieldTags: {
            if (!context.tags) {
                unknown = YES;
                result = @[];
            } else {
                result = NTYTUniqueStrings(context.tags, &unknown);
            }
            break;
        }

        default:
            unknown = YES;
            result = @[];
            break;
    }

    if (hasUnknown) {
        *hasUnknown = unknown;
    }

    return result ?: @[];
}

static NSNumber *NTYTBooleanValueForField(
    NTYTField field,
    NTYTRuleEvaluationContext *context
) {
    switch (field) {
        case NTYTFieldIsVideo:
            return context.isVideo;
        case NTYTFieldIsShort:
            return context.isShort;
        case NTYTFieldIsLive:
            return context.isLive;
        case NTYTFieldIsMember:
            return context.isMember;
        default:
            return nil;
    }
}

static NSNumber *NTYTNumericValueForField(
    NTYTField field,
    NTYTRuleEvaluationContext *context
) {
    switch (field) {
        case NTYTFieldViewCount:
            return context.approxViewCount;
        default:
            return nil;
    }
}

static NSRegularExpressionOptions NTYTRegexOptionsFromFlags(
    NSString *flags,
    BOOL *supported
) {
    NSRegularExpressionOptions options = 0;
    BOOL ok = YES;

    for (NSUInteger i = 0; i < flags.length; i++) {
        unichar c = [flags characterAtIndex:i];

        switch (c) {
            case 'i':
                options |= NSRegularExpressionCaseInsensitive;
                break;
            case 'm':
                options |= NSRegularExpressionAnchorsMatchLines;
                break;
            case 's':
                options |= NSRegularExpressionDotMatchesLineSeparators;
                break;
            case 'x':
                options |= NSRegularExpressionAllowCommentsAndWhitespace;
                break;
            case 'g':
                // Global has no effect when asking "does any match exist?"
                break;
            case 'u':
                // NSString / NSRegularExpression are Unicode-based.
                break;
            default:
                ok = NO;
                break;
        }

        if (!ok) {
            break;
        }
    }

    if (supported) {
        *supported = ok;
    }

    return options;
}

static NTYTMatchResult NTYTRegexMatch(
    NSString *candidate,
    NSString *pattern,
    NSString *flags,
    NSError **error
) {
    BOOL supported = YES;
    NSRegularExpressionOptions options =
        NTYTRegexOptionsFromFlags(flags ?: @"", &supported);

    if (!supported) {
        if (error) {
            *error = NTYTEvaluatorError(
                NTYTRuleEvaluatorErrorUnsupportedRegexFlag,
                [NSString stringWithFormat:
                    @"Unsupported regex flags: %@",
                    flags ?: @""]
            );
        }
        return NTYTMatchResultUnknown;
    }

    NSError *regexError = nil;
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:pattern
                                                  options:options
                                                    error:&regexError];

    if (!regex) {
        if (error) {
            *error = regexError ?: NTYTEvaluatorError(
                NTYTRuleEvaluatorErrorInvalidRegex,
                @"Invalid regular expression."
            );
        }
        return NTYTMatchResultUnknown;
    }

    NSRange fullRange = NSMakeRange(0, candidate.length);
    NSTextCheckingResult *match =
        [regex firstMatchInString:candidate
                          options:0
                            range:fullRange];

    return match
        ? NTYTMatchResultMatch
        : NTYTMatchResultNoMatch;
}

static NTYTMatchResult NTYTLiteralMatch(
    NSString *candidate,
    NSString *needle,
    NTYTMatcher matcher,
    BOOL caseSensitive,
    BOOL exactMatch,
    BOOL wordBoundary,
    NSError **error
) {
    if (![candidate isKindOfClass:[NSString class]] ||
        ![needle isKindOfClass:[NSString class]]) {
        if (error) {
            *error = NTYTEvaluatorError(
                NTYTRuleEvaluatorErrorInvalidConditionValue,
                @"Literal matcher requires string values."
            );
        }
        return NTYTMatchResultUnknown;
    }

    NSStringCompareOptions compareOptions =
        caseSensitive ? 0 : NSCaseInsensitiveSearch;

    BOOL useExact =
        matcher == NTYTMatcherExact ||
        (matcher == NTYTMatcherContains && exactMatch);

    if (useExact) {
        return [candidate compare:needle
                          options:compareOptions] == NSOrderedSame
            ? NTYTMatchResultMatch
            : NTYTMatchResultNoMatch;
    }

    if (wordBoundary) {
        NSString *escaped =
            [NSRegularExpression escapedPatternForString:needle];
        NSString *pattern =
            [NSString stringWithFormat:@"\\b(?:%@)\\b", escaped];

        NSString *flags = caseSensitive ? @"" : @"i";
        return NTYTRegexMatch(
            candidate,
            pattern,
            flags,
            error
        );
    }

    NSRange range =
        [candidate rangeOfString:needle
                         options:compareOptions];

    return range.location != NSNotFound
        ? NTYTMatchResultMatch
        : NTYTMatchResultNoMatch;
}

static NTYTMatchResult NTYTEvaluateStringCondition(
    NTYTCondition *condition,
    NTYTRuleEvaluationContext *context,
    NTYTRuleEvaluationOptions *defaults,
    NSError **error
) {
    if (![(id)condition.value isKindOfClass:[NSString class]]) {
        if (error) {
            *error = NTYTEvaluatorError(
                NTYTRuleEvaluatorErrorInvalidConditionValue,
                @"String matcher requires an NSString value."
            );
        }
        return NTYTMatchResultUnknown;
    }

    BOOL hasUnknown = NO;
    NSArray<NSString *> *candidates =
        NTYTStringCandidatesForField(
            condition.field,
            context,
            &hasUnknown
        );

    if (candidates.count == 0) {
        return NTYTMatchResultUnknown;
    }

    BOOL caseSensitive =
        NTYTEffectiveBool(
            defaults.caseSensitive,
            condition.caseSensitiveOverride
        );

    BOOL exactMatch =
        NTYTEffectiveBool(
            defaults.exactMatch,
            condition.exactMatchOverride
        );

    BOOL wordBoundary =
        NTYTEffectiveBool(
            defaults.wordBoundary,
            condition.wordBoundaryOverride
        );

    NSString *needle = (NSString *)condition.value;

    for (NSString *candidate in candidates) {
        NTYTMatchResult result;

        if (condition.matcher == NTYTMatcherRegex) {
            // Regex is authoritative. Literal section options do not alter
            // the regex body or flags.
            result = NTYTRegexMatch(
                candidate,
                needle,
                condition.regexFlags,
                error
            );
        } else {
            result = NTYTLiteralMatch(
                candidate,
                needle,
                condition.matcher,
                caseSensitive,
                exactMatch,
                wordBoundary,
                error
            );
        }

        if (result == NTYTMatchResultMatch) {
            return NTYTMatchResultMatch;
        }

        if (result == NTYTMatchResultUnknown) {
            hasUnknown = YES;
        }
    }

    return hasUnknown
        ? NTYTMatchResultUnknown
        : NTYTMatchResultNoMatch;
}

static NTYTMatchResult NTYTEvaluateBooleanCondition(
    NTYTCondition *condition,
    NTYTRuleEvaluationContext *context,
    NSError **error
) {
    if (![(id)condition.value isKindOfClass:[NSNumber class]]) {
        if (error) {
            *error = NTYTEvaluatorError(
                NTYTRuleEvaluatorErrorInvalidConditionValue,
                @"Boolean matcher requires an NSNumber value."
            );
        }
        return NTYTMatchResultUnknown;
    }

    NSNumber *actual =
        NTYTBooleanValueForField(condition.field, context);

    if (!actual) {
        return NTYTMatchResultUnknown;
    }

    BOOL expected = [(NSNumber *)condition.value boolValue];

    return actual.boolValue == expected
        ? NTYTMatchResultMatch
        : NTYTMatchResultNoMatch;
}

static NTYTMatchResult NTYTEvaluateNumericCondition(
    NTYTCondition *condition,
    NTYTRuleEvaluationContext *context,
    NSError **error
) {
    if (![(id)condition.value isKindOfClass:[NSNumber class]]) {
        if (error) {
            *error = NTYTEvaluatorError(
                NTYTRuleEvaluatorErrorInvalidConditionValue,
                @"Numeric matcher requires an NSNumber value."
            );
        }
        return NTYTMatchResultUnknown;
    }

    NSNumber *actual =
        NTYTNumericValueForField(condition.field, context);

    if (!actual) {
        return NTYTMatchResultUnknown;
    }

    double lhs = actual.doubleValue;
    double rhs = [(NSNumber *)condition.value doubleValue];
    BOOL match = NO;

    switch (condition.matcher) {
        case NTYTMatcherLessThan:
            match = lhs < rhs;
            break;
        case NTYTMatcherLessThanOrEqual:
            match = lhs <= rhs;
            break;
        case NTYTMatcherGreaterThan:
            match = lhs > rhs;
            break;
        case NTYTMatcherGreaterThanOrEqual:
            match = lhs >= rhs;
            break;
        default:
            return NTYTMatchResultUnknown;
    }

    return match
        ? NTYTMatchResultMatch
        : NTYTMatchResultNoMatch;
}

static NTYTMatchResult NTYTEvaluateCondition(
    NTYTCondition *condition,
    NTYTRuleEvaluationContext *context,
    NTYTRuleEvaluationOptions *defaults,
    NSError **error
) {
    NTYTMatchResult result = NTYTMatchResultUnknown;

    switch (condition.matcher) {
        case NTYTMatcherContains:
        case NTYTMatcherExact:
        case NTYTMatcherRegex:
            result = NTYTEvaluateStringCondition(
                condition,
                context,
                defaults,
                error
            );
            break;

        case NTYTMatcherBoolean:
            result = NTYTEvaluateBooleanCondition(
                condition,
                context,
                error
            );
            break;

        case NTYTMatcherLessThan:
        case NTYTMatcherLessThanOrEqual:
        case NTYTMatcherGreaterThan:
        case NTYTMatcherGreaterThanOrEqual:
            result = NTYTEvaluateNumericCondition(
                condition,
                context,
                error
            );
            break;

        case NTYTMatcherUnknown:
        default:
            result = NTYTMatchResultUnknown;
            break;
    }

    if (!condition.negated) {
        return result;
    }

    switch (result) {
        case NTYTMatchResultMatch:
            return NTYTMatchResultNoMatch;
        case NTYTMatchResultNoMatch:
            return NTYTMatchResultMatch;
        case NTYTMatchResultUnknown:
        default:
            return NTYTMatchResultUnknown;
    }
}

@implementation NTYTRuleEvaluator

+ (NTYTMatchResult)evaluateRule:(NTYTRule *)rule
                        context:(NTYTRuleEvaluationContext *)context
                 defaultOptions:(NTYTRuleEvaluationOptions *)defaultOptions
                          error:(NSError **)error {
    if (!rule.enabled) {
        return NTYTMatchResultNoMatch;
    }

    NTYTRuleEvaluationOptions *defaults =
        defaultOptions ?: [NTYTRuleEvaluationOptions defaultOptions];

    BOOL sawUnknown = NO;

    for (NTYTCondition *condition in rule.predicates) {
        NSError *conditionError = nil;
        NTYTMatchResult result =
            NTYTEvaluateCondition(
                condition,
                context,
                defaults,
                &conditionError
            );

        if (result == NTYTMatchResultNoMatch) {
            return NTYTMatchResultNoMatch;
        }

        if (result == NTYTMatchResultUnknown) {
            sawUnknown = YES;
            if (error && !*error && conditionError) {
                *error = conditionError;
            }
        }
    }

    return sawUnknown
        ? NTYTMatchResultUnknown
        : NTYTMatchResultMatch;
}

+ (NTYTMatchResult)evaluateAnyRule:(NSArray<NTYTRule *> *)rules
                           context:(NTYTRuleEvaluationContext *)context
          defaultOptionsBySection:
              (NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *)
                  defaultOptionsBySection {
    BOOL sawUnknown = NO;

    for (NTYTRule *rule in rules) {
        NTYTRuleEvaluationOptions *defaults =
            defaultOptionsBySection[rule.sourceSection];

        if (!defaults) {
            defaults = [NTYTRuleEvaluationOptions defaultOptions];
        }

        NTYTMatchResult result =
            [self evaluateRule:rule
                       context:context
                defaultOptions:defaults
                         error:nil];

        if (result == NTYTMatchResultMatch) {
            return NTYTMatchResultMatch;
        }

        if (result == NTYTMatchResultUnknown) {
            sawUnknown = YES;
        }
    }

    return sawUnknown
        ? NTYTMatchResultUnknown
        : NTYTMatchResultNoMatch;
}

+ (BOOL)shouldBlockContext:(NTYTRuleEvaluationContext *)context
                allowRules:(NSArray<NTYTRule *> *)allowRules
                blockRules:(NSArray<NTYTRule *> *)blockRules
   defaultOptionsBySection:
       (NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *)
           defaultOptionsBySection {
    NTYTMatchResult allowResult =
        [self evaluateAnyRule:allowRules
                      context:context
     defaultOptionsBySection:defaultOptionsBySection];

    if (allowResult == NTYTMatchResultMatch) {
        return NO;
    }

    NTYTMatchResult blockResult =
        [self evaluateAnyRule:blockRules
                      context:context
     defaultOptionsBySection:defaultOptionsBySection];

    return blockResult == NTYTMatchResultMatch;
}

@end
