#import "NTYTRuleParser.h"

NSErrorDomain const NTYTRuleParserErrorDomain =
    @"com.nothankyoutubetweak.ruleparser";

NSString * const NTYTRuleParserErrorOffsetKey =
    @"NTYTRuleParserErrorOffset";

NSString * const NTYTRuleParserErrorRuleIndexKey =
    @"NTYTRuleParserErrorRuleIndex";

@interface NTYTRuleParserResult ()

- (instancetype)initWithRules:(NSArray<NTYTRule *> *)rules
          unsupportedModifiers:(NSArray<NSString *> *)unsupportedModifiers;

@end

@implementation NTYTRuleParserResult

- (instancetype)initWithRules:(NSArray<NTYTRule *> *)rules
          unsupportedModifiers:(NSArray<NSString *> *)unsupportedModifiers {
    self = [super init];

    if (self) {
        _rules = [rules copy];
        _unsupportedModifiers = [unsupportedModifiers copy];
    }

    return self;
}

@end

@interface NTYTParserSlice : NSObject

@property (nonatomic, copy) NSString *text;
@property (nonatomic) NSUInteger sourceOffset;

@end

@implementation NTYTParserSlice
@end

@interface NTYTParsedMatchValue : NSObject

@property (nonatomic) NTYTMatcher matcher;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, copy, nullable) NSString *regexFlags;

@end

@implementation NTYTParsedMatchValue
@end

@interface NTYTParsedModifier : NSObject

@property (nonatomic, copy) NSString *normalizedName;
@property (nonatomic, copy) NSString *rawInner;
@property (nonatomic) BOOL negated;
@property (nonatomic) BOOL hasValue;
@property (nonatomic, strong, nullable) NTYTParsedMatchValue *parsedValue;
@property (nonatomic) NSUInteger sourceOffset;

@end

@implementation NTYTParsedModifier
@end

static NSError *NTYTParserError(
    NTYTRuleParserErrorCode code,
    NSString *description,
    NSUInteger offset,
    NSInteger ruleIndex
) {
    NSMutableDictionary *userInfo = [@{
        NSLocalizedDescriptionKey:
            description ?: @"Invalid advanced rule.",
        NTYTRuleParserErrorOffsetKey:
            @(offset),
    } mutableCopy];

    if (ruleIndex >= 0) {
        userInfo[NTYTRuleParserErrorRuleIndexKey] =
            @(ruleIndex);
    }

    return [NSError errorWithDomain:NTYTRuleParserErrorDomain
                               code:code
                           userInfo:userInfo];
}

static BOOL NTYTIsSpace(unichar c) {
    return [[NSCharacterSet whitespaceAndNewlineCharacterSet]
        characterIsMember:c];
}

static NSString *NTYTTrim(NSString *string) {
    return [string
        stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static BOOL NTYTBaseFieldIsAllowed(NTYTField field) {
    switch (field) {
        case NTYTFieldGeneralText:
        case NTYTFieldVideoText:
        case NTYTFieldChannelIdentity:
        case NTYTFieldVideoID:
            return YES;

        default:
            return NO;
    }
}

static NSString *NTYTUnescapeLiteral(NSString *string) {
    NSMutableString *result = [NSMutableString string];

    for (NSUInteger i = 0; i < string.length; i++) {
        unichar c = [string characterAtIndex:i];

        if (c != '\\' || i + 1 >= string.length) {
            [result appendFormat:@"%C", c];
            continue;
        }

        unichar next = [string characterAtIndex:i + 1];

        if (next == ',') {
            [result appendString:@","];
            i++;
            continue;
        }

        if (next == '\n') {
            [result appendString:@"\n"];
            i++;
            continue;
        }

        if (next == '\r') {
            [result appendString:@"\r"];
            i++;

            if (i + 1 < string.length &&
                [string characterAtIndex:i + 1] == '\n') {
                [result appendString:@"\n"];
                i++;
            }
            continue;
        }

        // Only comma / real line-break escaping is part of the documented
        // keyword syntax. Preserve every other backslash exactly.
        [result appendFormat:@"%C%C", c, next];
        i++;
    }

    return [result copy];
}

static BOOL NTYTCharacterCanBeRegexFlag(unichar c) {
    return
        (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z');
}

static NTYTParsedMatchValue *NTYTParseRegexLiteral(
    NSString *text,
    NSUInteger absoluteOffset,
    NSError **error
) {
    if (text.length == 0 ||
        [text characterAtIndex:0] != '/') {
        if (error) {
            *error = NTYTParserError(
                NTYTRuleParserErrorInvalidRegexLiteral,
                @"Regex literal must begin with '/'.",
                absoluteOffset,
                -1
            );
        }
        return nil;
    }

    BOOL escaped = NO;
    NSUInteger closingSlash = NSNotFound;

    for (NSUInteger i = 1; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];

        if (escaped) {
            escaped = NO;
            continue;
        }

        if (c == '\\') {
            escaped = YES;
            continue;
        }

        if (c == '/') {
            closingSlash = i;
            break;
        }
    }

    if (closingSlash == NSNotFound) {
        if (error) {
            *error = NTYTParserError(
                NTYTRuleParserErrorUnterminatedRegex,
                @"Unterminated regex literal.",
                absoluteOffset,
                -1
            );
        }
        return nil;
    }

    NSUInteger cursor = closingSlash + 1;
    NSMutableString *flags = [NSMutableString string];

    while (cursor < text.length) {
        unichar c = [text characterAtIndex:cursor];

        if (NTYTIsSpace(c)) {
            break;
        }

        if (!NTYTCharacterCanBeRegexFlag(c)) {
            if (error) {
                *error = NTYTParserError(
                    NTYTRuleParserErrorInvalidRegexLiteral,
                    @"Regex literal contains invalid trailing characters.",
                    absoluteOffset + cursor,
                    -1
                );
            }
            return nil;
        }

        [flags appendFormat:@"%C", c];
        cursor++;
    }

    while (cursor < text.length &&
           NTYTIsSpace([text characterAtIndex:cursor])) {
        cursor++;
    }

    if (cursor != text.length) {
        if (error) {
            *error = NTYTParserError(
                NTYTRuleParserErrorInvalidRegexLiteral,
                @"Unexpected text after regex flags.",
                absoluteOffset + cursor,
                -1
            );
        }
        return nil;
    }

    NTYTParsedMatchValue *value =
        [[NTYTParsedMatchValue alloc] init];

    value.matcher = NTYTMatcherRegex;
    value.value =
        [text substringWithRange:
            NSMakeRange(1, closingSlash - 1)];
    value.regexFlags =
        flags.length > 0 ? [flags copy] : nil;

    return value;
}

static NTYTParsedMatchValue *NTYTParseMatchValue(
    NSString *rawValue,
    NSUInteger absoluteOffset,
    NSError **error
) {
    NSString *trimmed = NTYTTrim(rawValue);

    if (trimmed.length == 0) {
        if (error) {
            *error = NTYTParserError(
                NTYTRuleParserErrorMissingModifierValue,
                @"Modifier value is empty.",
                absoluteOffset,
                -1
            );
        }
        return nil;
    }

    if ([trimmed characterAtIndex:0] == '/') {
        return NTYTParseRegexLiteral(
            trimmed,
            absoluteOffset,
            error
        );
    }

    NTYTParsedMatchValue *value =
        [[NTYTParsedMatchValue alloc] init];

    value.matcher = NTYTMatcherContains;
    value.value = NTYTUnescapeLiteral(trimmed);
    value.regexFlags = nil;

    return value;
}

static NSString *NTYTCanonicalModifierName(NSString *name) {
    NSString *n = [name lowercaseString];

    if ([n isEqualToString:@"casesensitive"] ||
        [n isEqualToString:@"cs"]) {
        return @"cs";
    }

    if ([n isEqualToString:@"exact"] ||
        [n isEqualToString:@"em"] ||
        [n isEqualToString:@"exactmatch"]) {
        return @"exact";
    }

    if ([n isEqualToString:@"bound"] ||
        [n isEqualToString:@"wb"] ||
        [n isEqualToString:@"wordbound"]) {
        return @"bound";
    }

    if ([n isEqualToString:@"overlay"] ||
        [n isEqualToString:@"ov"]) {
        return @"overlay";
    }

    if ([n isEqualToString:@"shorts"] ||
        [n isEqualToString:@"short"]) {
        return @"short";
    }

    if ([n isEqualToString:@"live"] ||
        [n isEqualToString:@"lives"]) {
        return @"live";
    }

    if ([n isEqualToString:@"premiere"] ||
        [n isEqualToString:@"upcoming"]) {
        return @"premiere";
    }

    if ([n isEqualToString:@"member"] ||
        [n isEqualToString:@"member-only"]) {
        return @"member";
    }

    if ([n isEqualToString:@"duration"] ||
        [n isEqualToString:@"length"]) {
        return @"duration";
    }

    if ([n isEqualToString:@"minduration"] ||
        [n isEqualToString:@"minlength"] ||
        [n isEqualToString:@"shorter"]) {
        return @"minduration";
    }

    if ([n isEqualToString:@"older"] ||
        [n isEqualToString:@"old"]) {
        return @"older";
    }

    if ([n isEqualToString:@"newer"] ||
        [n isEqualToString:@"new"]) {
        return @"newer";
    }

    if ([n isEqualToString:@"content"] ||
        [n isEqualToString:@"text"] ||
        [n isEqualToString:@"ctn"] ||
        [n isEqualToString:@"title"] ||
        [n isEqualToString:@"tt"]) {
        return @"content";
    }

    if ([n isEqualToString:@"description"] ||
        [n isEqualToString:@"desc"]) {
        return @"description";
    }

    if ([n isEqualToString:@"tag"] ||
        [n isEqualToString:@"tags"]) {
        return @"tag";
    }

    if ([n isEqualToString:@"channel"] ||
        [n isEqualToString:@"user"] ||
        [n isEqualToString:@"ch"]) {
        return @"channel";
    }

    if ([n isEqualToString:@"video"] ||
        [n isEqualToString:@"isvideo"]) {
        return @"video";
    }

    if ([n isEqualToString:@"comment"] ||
        [n isEqualToString:@"iscomment"]) {
        return @"comment";
    }

    if ([n isEqualToString:@"post"] ||
        [n isEqualToString:@"ispost"]) {
        return @"post";
    }

    if ([n isEqualToString:@"isplaylistvideo"] ||
        [n isEqualToString:@"pv"]) {
        return @"isplaylistvideo";
    }

    if ([n isEqualToString:@"page"] ||
        [n isEqualToString:@"p"]) {
        return @"page";
    }

    if ([n isEqualToString:@"restricted"] ||
        [n isEqualToString:@"age"] ||
        [n isEqualToString:@"age-restricted"]) {
        return @"restricted";
    }

    // Unknown names are syntactically valid modifiers, but not implemented.
    // Preserve a normalized name and compile them fail-safe as UNKNOWN.
    return n;
}

static BOOL NTYTModifierNameRequiresValue(NSString *name) {
    return
        [name isEqualToString:@"duration"] ||
        [name isEqualToString:@"minduration"] ||
        [name isEqualToString:@"older"] ||
        [name isEqualToString:@"newer"] ||
        [name isEqualToString:@"content"] ||
        [name isEqualToString:@"description"] ||
        [name isEqualToString:@"tag"] ||
        [name isEqualToString:@"channel"] ||
        [name isEqualToString:@"page"];
}

static BOOL NTYTModifierNameForbidsValue(NSString *name) {
    return
        [name isEqualToString:@"cs"] ||
        [name isEqualToString:@"exact"] ||
        [name isEqualToString:@"bound"] ||
        [name isEqualToString:@"overlay"] ||
        [name isEqualToString:@"short"] ||
        [name isEqualToString:@"live"] ||
        [name isEqualToString:@"premiere"] ||
        [name isEqualToString:@"member"] ||
        [name isEqualToString:@"comment"] ||
        [name isEqualToString:@"post"] ||
        [name isEqualToString:@"isplaylistvideo"] ||
        [name isEqualToString:@"restricted"];
}

static NTYTParsedModifier *NTYTParseModifier(
    NSString *ruleText,
    NSUInteger *ioCursor,
    NSUInteger ruleSourceOffset,
    NSError **error
) {
    NSUInteger cursor = *ioCursor;

    if (cursor + 1 >= ruleText.length ||
        [ruleText characterAtIndex:cursor] != '$' ||
        [ruleText characterAtIndex:cursor + 1] != '{') {
        if (error) {
            *error = NTYTParserError(
                NTYTRuleParserErrorInvalidModifier,
                @"Expected '${' modifier opener.",
                ruleSourceOffset + cursor,
                -1
            );
        }
        return nil;
    }

    NSUInteger innerStart = cursor + 2;
    NSUInteger i = innerStart;

    BOOL sawColon = NO;
    BOOL valueStarted = NO;
    BOOL inValueRegex = NO;
    BOOL regexEscaped = NO;
    NSUInteger closingBrace = NSNotFound;

    for (; i < ruleText.length; i++) {
        unichar c = [ruleText characterAtIndex:i];

        if (inValueRegex) {
            if (regexEscaped) {
                regexEscaped = NO;
                continue;
            }

            if (c == '\\') {
                regexEscaped = YES;
                continue;
            }

            if (c == '/') {
                inValueRegex = NO;
            }

            continue;
        }

        if (c == '}') {
            closingBrace = i;
            break;
        }

        if (!sawColon) {
            if (c == ':') {
                sawColon = YES;
            }
            continue;
        }

        if (!valueStarted) {
            if (NTYTIsSpace(c)) {
                continue;
            }

            valueStarted = YES;

            if (c == '/') {
                inValueRegex = YES;
            }
        }
    }

    if (closingBrace == NSNotFound) {
        if (error) {
            *error = NTYTParserError(
                inValueRegex
                    ? NTYTRuleParserErrorUnterminatedRegex
                    : NTYTRuleParserErrorUnterminatedModifier,
                inValueRegex
                    ? @"Unterminated regex inside modifier."
                    : @"Unterminated modifier.",
                ruleSourceOffset + cursor,
                -1
            );
        }
        return nil;
    }

    NSString *inner =
        [ruleText substringWithRange:
            NSMakeRange(
                innerStart,
                closingBrace - innerStart
            )];

    NSString *trimmed = NTYTTrim(inner);

    if (trimmed.length == 0) {
        if (error) {
            *error = NTYTParserError(
                NTYTRuleParserErrorInvalidModifier,
                @"Modifier name is empty.",
                ruleSourceOffset + cursor,
                -1
            );
        }
        return nil;
    }

    BOOL negated = NO;

    if ([trimmed characterAtIndex:0] == '!') {
        negated = YES;
        trimmed =
            NTYTTrim([trimmed substringFromIndex:1]);

        if (trimmed.length == 0) {
            if (error) {
                *error = NTYTParserError(
                    NTYTRuleParserErrorInvalidModifier,
                    @"Modifier name is empty after '!'.",
                    ruleSourceOffset + cursor,
                    -1
                );
            }
            return nil;
        }
    }

    NSRange colon =
        [trimmed rangeOfString:@":"];

    NSString *namePart = nil;
    NSString *valuePart = nil;
    BOOL hasValue = colon.location != NSNotFound;

    if (hasValue) {
        namePart =
            NTYTTrim(
                [trimmed substringToIndex:colon.location]
            );
        valuePart =
            NTYTTrim(
                [trimmed substringFromIndex:
                    colon.location + 1]
            );
    } else {
        namePart = NTYTTrim(trimmed);
    }

    if (namePart.length == 0) {
        if (error) {
            *error = NTYTParserError(
                NTYTRuleParserErrorInvalidModifier,
                @"Modifier name is empty.",
                ruleSourceOffset + cursor,
                -1
            );
        }
        return nil;
    }

    NSString *canonical =
        NTYTCanonicalModifierName(namePart);

    if (NTYTModifierNameRequiresValue(canonical) &&
        (!hasValue || valuePart.length == 0)) {
        if (error) {
            *error = NTYTParserError(
                NTYTRuleParserErrorMissingModifierValue,
                [NSString stringWithFormat:
                    @"Modifier '%@' requires a value.",
                    canonical],
                ruleSourceOffset + cursor,
                -1
            );
        }
        return nil;
    }

    if (NTYTModifierNameForbidsValue(canonical) &&
        hasValue) {
        if (error) {
            *error = NTYTParserError(
                NTYTRuleParserErrorUnexpectedModifierValue,
                [NSString stringWithFormat:
                    @"Modifier '%@' does not take a value.",
                    canonical],
                ruleSourceOffset + cursor,
                -1
            );
        }
        return nil;
    }

    // Frozen NTYT behavior intentionally extends YTBlock's documented
    // ${video} form with ${video: VALUE}.
    if ([canonical isEqualToString:@"video"]) {
        // Optional value is valid.
    }

    NTYTParsedModifier *modifier =
        [[NTYTParsedModifier alloc] init];

    modifier.normalizedName = canonical;
    modifier.rawInner = inner;
    modifier.negated = negated;
    modifier.hasValue = hasValue;
    modifier.sourceOffset = ruleSourceOffset + cursor;

    if (hasValue) {
        NSUInteger valueOffset =
            modifier.sourceOffset + 2 +
            colon.location + 1;

        NSError *valueError = nil;
        modifier.parsedValue =
            NTYTParseMatchValue(
                valuePart,
                valueOffset,
                &valueError
            );

        if (!modifier.parsedValue) {
            if (error) {
                *error = valueError;
            }
            return nil;
        }
    }

    *ioCursor = closingBrace + 1;
    return modifier;
}

static NTYTCondition *NTYTTextCondition(
    NTYTField field,
    NTYTParsedMatchValue *parsedValue,
    BOOL negated,
    NTYTOptionOverride caseSensitive,
    NTYTOptionOverride exactMatch,
    NTYTOptionOverride wordBoundary
) {
    return [[NTYTCondition alloc]
        initWithField:field
        matcher:parsedValue.matcher
        value:parsedValue.value
        regexFlags:parsedValue.regexFlags
        negated:negated
        caseSensitiveOverride:caseSensitive
        exactMatchOverride:exactMatch
        wordBoundaryOverride:wordBoundary];
}

static NTYTCondition *NTYTBooleanCondition(
    NTYTField field,
    BOOL negated
) {
    return [[NTYTCondition alloc]
        initWithField:field
        matcher:NTYTMatcherBoolean
        value:@YES
        regexFlags:nil
        negated:negated
        caseSensitiveOverride:NTYTOptionOverrideInherit
        exactMatchOverride:NTYTOptionOverrideInherit
        wordBoundaryOverride:NTYTOptionOverrideInherit];
}

static NTYTCondition *NTYTUnsupportedCondition(
    NTYTParsedModifier *modifier
) {
    NSString *descriptor =
        [NSString stringWithFormat:
            @"${%@}",
            NTYTTrim(modifier.rawInner)];

    return [[NTYTCondition alloc]
        initWithField:NTYTFieldUnsupported
        matcher:NTYTMatcherContains
        value:descriptor
        regexFlags:nil
        negated:modifier.negated
        caseSensitiveOverride:NTYTOptionOverrideInherit
        exactMatchOverride:NTYTOptionOverrideInherit
        wordBoundaryOverride:NTYTOptionOverrideInherit];
}

static BOOL NTYTAddModifierPredicate(
    NTYTParsedModifier *modifier,
    NSMutableArray<NTYTCondition *> *conditions,
    NSMutableOrderedSet<NSString *> *unsupportedModifiers,
    NTYTOptionOverride *caseSensitive,
    NTYTOptionOverride *exactMatch,
    NTYTOptionOverride *wordBoundary,
    NSError **error
) {
    NSString *name = modifier.normalizedName;

    if ([name isEqualToString:@"cs"]) {
        *caseSensitive = modifier.negated
            ? NTYTOptionOverrideForceOff
            : NTYTOptionOverrideForceOn;
        return YES;
    }

    if ([name isEqualToString:@"exact"]) {
        *exactMatch = modifier.negated
            ? NTYTOptionOverrideForceOff
            : NTYTOptionOverrideForceOn;
        return YES;
    }

    if ([name isEqualToString:@"bound"]) {
        *wordBoundary = modifier.negated
            ? NTYTOptionOverrideForceOff
            : NTYTOptionOverrideForceOn;
        return YES;
    }

    if ([name isEqualToString:@"content"]) {
        [conditions addObject:
            NTYTTextCondition(
                NTYTFieldContentText,
                modifier.parsedValue,
                modifier.negated,
                NTYTOptionOverrideInherit,
                NTYTOptionOverrideInherit,
                NTYTOptionOverrideInherit
            )];
        return YES;
    }

    if ([name isEqualToString:@"description"]) {
        [conditions addObject:
            NTYTTextCondition(
                NTYTFieldDescription,
                modifier.parsedValue,
                modifier.negated,
                NTYTOptionOverrideInherit,
                NTYTOptionOverrideInherit,
                NTYTOptionOverrideInherit
            )];
        return YES;
    }

    if ([name isEqualToString:@"tag"]) {
        [conditions addObject:
            NTYTTextCondition(
                NTYTFieldTags,
                modifier.parsedValue,
                modifier.negated,
                NTYTOptionOverrideInherit,
                NTYTOptionOverrideInherit,
                NTYTOptionOverrideInherit
            )];
        return YES;
    }

    if ([name isEqualToString:@"channel"]) {
        NTYTParsedMatchValue *channelValue =
            modifier.parsedValue;

        NTYTParsedMatchValue *effectiveValue =
            channelValue;

        if (channelValue.matcher == NTYTMatcherContains) {
            effectiveValue =
                [[NTYTParsedMatchValue alloc] init];
            effectiveValue.matcher = NTYTMatcherExact;
            effectiveValue.value = channelValue.value;
            effectiveValue.regexFlags = nil;
        }

        [conditions addObject:
            NTYTTextCondition(
                NTYTFieldChannelIdentity,
                effectiveValue,
                modifier.negated,
                NTYTOptionOverrideInherit,
                NTYTOptionOverrideInherit,
                NTYTOptionOverrideInherit
            )];
        return YES;
    }

    if ([name isEqualToString:@"video"]) {
        if (!modifier.hasValue) {
            [conditions addObject:
                NTYTBooleanCondition(
                    NTYTFieldIsVideo,
                    modifier.negated
                )];
            return YES;
        }

        if (!modifier.negated) {
            [conditions addObject:
                NTYTBooleanCondition(
                    NTYTFieldIsVideo,
                    NO
                )];

            [conditions addObject:
                NTYTTextCondition(
                    NTYTFieldVideoText,
                    modifier.parsedValue,
                    NO,
                    NTYTOptionOverrideInherit,
                    NTYTOptionOverrideInherit,
                    NTYTOptionOverrideInherit
                )];
            return YES;
        }

        // The design freezes ${video: VALUE} as:
        // is_video AND video_text(value). It does not define a safe boolean
        // algebra for negating that compound expression. Do not guess.
        [unsupportedModifiers addObject:@"!video:value"];
        [conditions addObject:
            NTYTUnsupportedCondition(modifier)];
        return YES;
    }

    if ([name isEqualToString:@"short"]) {
        [conditions addObject:
            NTYTBooleanCondition(
                NTYTFieldIsShort,
                modifier.negated
            )];
        return YES;
    }

    if ([name isEqualToString:@"live"]) {
        [conditions addObject:
            NTYTBooleanCondition(
                NTYTFieldIsLive,
                modifier.negated
            )];
        return YES;
    }

    if ([name isEqualToString:@"member"]) {
        [conditions addObject:
            NTYTBooleanCondition(
                NTYTFieldIsMember,
                modifier.negated
            )];
        return YES;
    }

    // Syntactically valid, documented modifiers whose data provider / runtime
    // behavior is not available in NTYT v1. They must not be ignored.
    static NSSet<NSString *> *knownUnsupported = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        knownUnsupported = [NSSet setWithArray:@[
            @"overlay",
            @"premiere",
            @"duration",
            @"minduration",
            @"older",
            @"newer",
            @"comment",
            @"post",
            @"isplaylistvideo",
            @"page",
            @"restricted",
        ]];
    });

    if ([knownUnsupported containsObject:name] ||
        name.length > 0) {
        [unsupportedModifiers addObject:name];
        [conditions addObject:
            NTYTUnsupportedCondition(modifier)];
        return YES;
    }

    if (error) {
        *error = NTYTParserError(
            NTYTRuleParserErrorInvalidModifier,
            @"Invalid modifier.",
            modifier.sourceOffset,
            -1
        );
    }
    return NO;
}

static BOOL NTYTSourceCharIsEnabledSeparator(
    unichar c,
    NTYTRuleParserSeparators separators
) {
    if (c == ',' &&
        (separators & NTYTRuleParserSeparatorComma)) {
        return YES;
    }

    if ((c == '\n' || c == '\r') &&
        (separators & NTYTRuleParserSeparatorNewline)) {
        return YES;
    }

    return NO;
}

static NSArray<NTYTParserSlice *> *NTYTSplitSource(
    NSString *source,
    NTYTRuleParserSeparators separators,
    NSError **error
) {
    NSMutableArray<NTYTParserSlice *> *slices =
        [NSMutableArray array];

    NSUInteger sliceStart = 0;

    BOOL inRegex = NO;
    BOOL regexEscaped = NO;

    BOOL inModifier = NO;
    BOOL modifierSawColon = NO;
    BOOL modifierValueStarted = NO;
    BOOL modifierValueRegex = NO;
    BOOL modifierRegexEscaped = NO;

    BOOL baseStarted = NO;
    BOOL escapeNext = NO;

    for (NSUInteger i = 0; i < source.length; i++) {
        unichar c = [source characterAtIndex:i];

        if (inRegex) {
            if (regexEscaped) {
                regexEscaped = NO;
                continue;
            }

            if (c == '\\') {
                regexEscaped = YES;
                continue;
            }

            if (c == '/') {
                inRegex = NO;
            }

            continue;
        }

        if (inModifier) {
            if (modifierValueRegex) {
                if (modifierRegexEscaped) {
                    modifierRegexEscaped = NO;
                    continue;
                }

                if (c == '\\') {
                    modifierRegexEscaped = YES;
                    continue;
                }

                if (c == '/') {
                    modifierValueRegex = NO;
                }

                continue;
            }

            if (c == '}') {
                inModifier = NO;
                continue;
            }

            if (!modifierSawColon) {
                if (c == ':') {
                    modifierSawColon = YES;
                }
                continue;
            }

            if (!modifierValueStarted) {
                if (NTYTIsSpace(c)) {
                    continue;
                }

                modifierValueStarted = YES;

                if (c == '/') {
                    modifierValueRegex = YES;
                }
            }

            continue;
        }

        if (escapeNext) {
            escapeNext = NO;
            baseStarted = YES;

            if (c == '\r' &&
                i + 1 < source.length &&
                [source characterAtIndex:i + 1] == '\n') {
                i++;
            }
            continue;
        }

        if (c == '\\') {
            escapeNext = YES;
            baseStarted = YES;
            continue;
        }

        if (!baseStarted &&
            c == '$' &&
            i + 1 < source.length &&
            [source characterAtIndex:i + 1] == '{') {
            inModifier = YES;
            modifierSawColon = NO;
            modifierValueStarted = NO;
            modifierValueRegex = NO;
            modifierRegexEscaped = NO;
            i++;
            continue;
        }

        if (NTYTSourceCharIsEnabledSeparator(
                c,
                separators
            )) {
            NSString *piece =
                [source substringWithRange:
                    NSMakeRange(
                        sliceStart,
                        i - sliceStart
                    )];

            if (NTYTTrim(piece).length > 0) {
                NTYTParserSlice *slice =
                    [[NTYTParserSlice alloc] init];
                slice.text = piece;
                slice.sourceOffset = sliceStart;
                [slices addObject:slice];
            }

            if (c == '\r' &&
                i + 1 < source.length &&
                [source characterAtIndex:i + 1] == '\n') {
                i++;
            }

            sliceStart = i + 1;
            baseStarted = NO;
            continue;
        }

        if (c == '$' &&
            i + 1 < source.length &&
            [source characterAtIndex:i + 1] == '&') {
            baseStarted = NO;
            i++;
            continue;
        }

        if (NTYTIsSpace(c)) {
            continue;
        }

        if (!baseStarted && c == '!') {
            continue;
        }

        if (!baseStarted && c == '/') {
            inRegex = YES;
            regexEscaped = NO;
            baseStarted = YES;
            continue;
        }

        baseStarted = YES;
    }

    if (inRegex) {
        if (error) {
            *error = NTYTParserError(
                NTYTRuleParserErrorUnterminatedRegex,
                @"Unterminated regex literal in source.",
                source.length,
                -1
            );
        }
        return nil;
    }

    if (inModifier) {
        if (error) {
            *error = NTYTParserError(
                modifierValueRegex
                    ? NTYTRuleParserErrorUnterminatedRegex
                    : NTYTRuleParserErrorUnterminatedModifier,
                modifierValueRegex
                    ? @"Unterminated regex inside modifier."
                    : @"Unterminated modifier in source.",
                source.length,
                -1
            );
        }
        return nil;
    }

    if (sliceStart <= source.length) {
        NSString *piece =
            [source substringFromIndex:sliceStart];

        if (NTYTTrim(piece).length > 0) {
            NTYTParserSlice *slice =
                [[NTYTParserSlice alloc] init];
            slice.text = piece;
            slice.sourceOffset = sliceStart;
            [slices addObject:slice];
        }
    }

    return [slices copy];
}

static void NTYTSkipWhitespace(
    NSString *text,
    NSUInteger *ioCursor
) {
    NSUInteger cursor = *ioCursor;

    while (cursor < text.length &&
           NTYTIsSpace([text characterAtIndex:cursor])) {
        cursor++;
    }

    *ioCursor = cursor;
}

static NSUInteger NTYTFindNextAndOperator(
    NSString *text,
    NSUInteger start
) {
    if (start >= text.length) {
        return NSNotFound;
    }

    NSRange range =
        [text rangeOfString:@"$&"
                    options:0
                      range:
            NSMakeRange(
                start,
                text.length - start
            )];

    return range.location;
}

static NTYTParsedMatchValue *NTYTParseRegexAtCursor(
    NSString *text,
    NSUInteger *ioCursor,
    NSUInteger ruleSourceOffset,
    NSError **error
) {
    NSUInteger start = *ioCursor;
    BOOL escaped = NO;
    NSUInteger closingSlash = NSNotFound;

    for (NSUInteger i = start + 1; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];

        if (escaped) {
            escaped = NO;
            continue;
        }

        if (c == '\\') {
            escaped = YES;
            continue;
        }

        if (c == '/') {
            closingSlash = i;
            break;
        }
    }

    if (closingSlash == NSNotFound) {
        if (error) {
            *error = NTYTParserError(
                NTYTRuleParserErrorUnterminatedRegex,
                @"Unterminated regex literal.",
                ruleSourceOffset + start,
                -1
            );
        }
        return nil;
    }

    NSUInteger cursor = closingSlash + 1;

    while (cursor < text.length &&
           NTYTCharacterCanBeRegexFlag(
               [text characterAtIndex:cursor]
           )) {
        cursor++;
    }

    NSString *literal =
        [text substringWithRange:
            NSMakeRange(
                start,
                cursor - start
            )];

    NSError *regexError = nil;
    NTYTParsedMatchValue *parsed =
        NTYTParseRegexLiteral(
            literal,
            ruleSourceOffset + start,
            &regexError
        );

    if (!parsed) {
        if (error) {
            *error = regexError;
        }
        return nil;
    }

    *ioCursor = cursor;
    return parsed;
}

static NTYTRule *NTYTParseRuleSlice(
    NTYTParserSlice *slice,
    NSString *identifier,
    NSString *sourceSection,
    NTYTField baseField,
    NSMutableOrderedSet<NSString *> *unsupportedModifiers,
    NSError **error
) {
    NSString *ruleText = NTYTTrim(slice.text);
    NSUInteger leadingTrim =
        [slice.text rangeOfString:ruleText].location;

    if (leadingTrim == NSNotFound) {
        leadingTrim = 0;
    }

    NSUInteger ruleOffset =
        slice.sourceOffset + leadingTrim;

    NSUInteger cursor = 0;
    NSMutableArray<NTYTCondition *> *predicates =
        [NSMutableArray array];

    while (cursor < ruleText.length) {
        NTYTSkipWhitespace(ruleText, &cursor);

        if (cursor >= ruleText.length) {
            break;
        }

        NTYTOptionOverride caseSensitive =
            NTYTOptionOverrideInherit;
        NTYTOptionOverride exactMatch =
            NTYTOptionOverrideInherit;
        NTYTOptionOverride wordBoundary =
            NTYTOptionOverrideInherit;

        NSMutableArray<NTYTCondition *> *modifierPredicates =
            [NSMutableArray array];

        while (cursor + 1 < ruleText.length &&
               [ruleText characterAtIndex:cursor] == '$' &&
               [ruleText characterAtIndex:cursor + 1] == '{') {
            NSError *modifierError = nil;
            NTYTParsedModifier *modifier =
                NTYTParseModifier(
                    ruleText,
                    &cursor,
                    ruleOffset,
                    &modifierError
                );

            if (!modifier) {
                if (error) {
                    *error = modifierError;
                }
                return nil;
            }

            NSError *applyError = nil;
            if (!NTYTAddModifierPredicate(
                    modifier,
                    modifierPredicates,
                    unsupportedModifiers,
                    &caseSensitive,
                    &exactMatch,
                    &wordBoundary,
                    &applyError
                )) {
                if (error) {
                    *error = applyError;
                }
                return nil;
            }

            NTYTSkipWhitespace(ruleText, &cursor);
        }

        if (cursor >= ruleText.length) {
            if (error) {
                *error = NTYTParserError(
                    NTYTRuleParserErrorMissingKeyword,
                    @"Modifiers must be followed by a keyword or regex.",
                    ruleOffset + cursor,
                    -1
                );
            }
            return nil;
        }

        BOOL negated = NO;

        if ([ruleText characterAtIndex:cursor] == '!') {
            negated = YES;
            cursor++;
            NTYTSkipWhitespace(ruleText, &cursor);

            if (cursor >= ruleText.length) {
                if (error) {
                    *error = NTYTParserError(
                        NTYTRuleParserErrorMissingKeyword,
                        @"'!' must be followed by a keyword or regex.",
                        ruleOffset + cursor,
                        -1
                    );
                }
                return nil;
            }
        }

        NTYTParsedMatchValue *baseValue = nil;

        if ([ruleText characterAtIndex:cursor] == '/') {
            NSError *regexError = nil;
            baseValue =
                NTYTParseRegexAtCursor(
                    ruleText,
                    &cursor,
                    ruleOffset,
                    &regexError
                );

            if (!baseValue) {
                if (error) {
                    *error = regexError;
                }
                return nil;
            }

            NTYTSkipWhitespace(ruleText, &cursor);

            if (cursor < ruleText.length) {
                if (!(cursor + 1 < ruleText.length &&
                      [ruleText characterAtIndex:cursor] == '$' &&
                      [ruleText characterAtIndex:cursor + 1] == '&')) {
                    if (error) {
                        *error = NTYTParserError(
                            NTYTRuleParserErrorInvalidRegexLiteral,
                            @"Unexpected text after regex before '$&'.",
                            ruleOffset + cursor,
                            -1
                        );
                    }
                    return nil;
                }
            }
        } else {
            NSUInteger andLocation =
                NTYTFindNextAndOperator(
                    ruleText,
                    cursor
                );

            NSUInteger end =
                andLocation == NSNotFound
                    ? ruleText.length
                    : andLocation;

            NSString *literal =
                [ruleText substringWithRange:
                    NSMakeRange(
                        cursor,
                        end - cursor
                    )];

            literal = NTYTTrim(literal);

            if (literal.length == 0) {
                if (error) {
                    *error = NTYTParserError(
                        NTYTRuleParserErrorEmptyAndOperand,
                        @"Empty operand around '$&'.",
                        ruleOffset + cursor,
                        -1
                    );
                }
                return nil;
            }

            if ([literal rangeOfString:@"${"].location != NSNotFound) {
                if (error) {
                    *error = NTYTParserError(
                        NTYTRuleParserErrorInvalidModifier,
                        @"Modifier must appear before its keyword.",
                        ruleOffset + cursor,
                        -1
                    );
                }
                return nil;
            }

            baseValue =
                [[NTYTParsedMatchValue alloc] init];
            baseValue.matcher = NTYTMatcherContains;
            baseValue.value =
                NTYTUnescapeLiteral(literal);
            baseValue.regexFlags = nil;

            cursor = end;
        }

        NTYTCondition *baseCondition =
            NTYTTextCondition(
                baseField,
                baseValue,
                negated,
                caseSensitive,
                exactMatch,
                wordBoundary
            );

        // Put the base predicate first. It is usually the cheapest predicate,
        // and lets the evaluator return NO_MATCH before touching an UNKNOWN
        // future-provider predicate when the base text already does not match.
        [predicates addObject:baseCondition];
        [predicates addObjectsFromArray:modifierPredicates];

        NTYTSkipWhitespace(ruleText, &cursor);

        if (cursor >= ruleText.length) {
            break;
        }

        if (!(cursor + 1 < ruleText.length &&
              [ruleText characterAtIndex:cursor] == '$' &&
              [ruleText characterAtIndex:cursor + 1] == '&')) {
            if (error) {
                *error = NTYTParserError(
                    NTYTRuleParserErrorEmptyAndOperand,
                    @"Expected '$&' between rule operands.",
                    ruleOffset + cursor,
                    -1
                );
            }
            return nil;
        }

        cursor += 2;
        NTYTSkipWhitespace(ruleText, &cursor);

        if (cursor >= ruleText.length) {
            if (error) {
                *error = NTYTParserError(
                    NTYTRuleParserErrorEmptyAndOperand,
                    @"'$&' is missing its right operand.",
                    ruleOffset + cursor,
                    -1
                );
            }
            return nil;
        }
    }

    if (predicates.count == 0) {
        if (error) {
            *error = NTYTParserError(
                NTYTRuleParserErrorMissingKeyword,
                @"Rule does not contain a keyword or regex.",
                ruleOffset,
                -1
            );
        }
        return nil;
    }

    return [[NTYTRule alloc]
        initWithIdentifier:identifier
        enabled:YES
        group:nil
        sourceSection:sourceSection
        baseField:baseField
        sourceText:ruleText
        predicates:predicates];
}

@implementation NTYTRuleParser

+ (NTYTRuleParserResult *)parseSource:(NSString *)source
                         sourceSection:(NSString *)sourceSection
                             baseField:(NTYTField)baseField
                      identifierPrefix:(NSString *)identifierPrefix
                                 error:(NSError **)error {
    return [self parseSource:source
                sourceSection:sourceSection
                    baseField:baseField
             identifierPrefix:identifierPrefix
                   separators:NTYTRuleParserSeparatorDefault
                        error:error];
}

+ (NTYTRuleParserResult *)parseSource:(NSString *)source
                         sourceSection:(NSString *)sourceSection
                             baseField:(NTYTField)baseField
                      identifierPrefix:(NSString *)identifierPrefix
                            separators:(NTYTRuleParserSeparators)separators
                                 error:(NSError **)error {
    if (![source isKindOfClass:[NSString class]] ||
        ![sourceSection isKindOfClass:[NSString class]] ||
        sourceSection.length == 0) {
        if (error) {
            *error = NTYTParserError(
                NTYTRuleParserErrorInvalidArgument,
                @"Parser requires source text and a non-empty sourceSection.",
                0,
                -1
            );
        }
        return nil;
    }

    if (!NTYTBaseFieldIsAllowed(baseField)) {
        if (error) {
            *error = NTYTParserError(
                NTYTRuleParserErrorInvalidBaseField,
                @"baseField must be general_text, video_text, channel_identity, or video_id.",
                0,
                -1
            );
        }
        return nil;
    }

    NSError *splitError = nil;
    NSArray<NTYTParserSlice *> *slices =
        NTYTSplitSource(
            source,
            separators,
            &splitError
        );

    if (!slices) {
        if (error) {
            *error = splitError;
        }
        return nil;
    }

    NSString *prefix =
        identifierPrefix.length > 0
            ? identifierPrefix
            : @"advanced";

    NSMutableArray<NTYTRule *> *rules =
        [NSMutableArray arrayWithCapacity:slices.count];

    NSMutableOrderedSet<NSString *> *unsupported =
        [NSMutableOrderedSet orderedSet];

    for (NSUInteger i = 0; i < slices.count; i++) {
        NTYTParserSlice *slice = slices[i];

        NSString *identifier =
            [NSString stringWithFormat:
                @"%@.%lu",
                prefix,
                (unsigned long)(i + 1)];

        NSError *ruleError = nil;
        NTYTRule *rule =
            NTYTParseRuleSlice(
                slice,
                identifier,
                sourceSection,
                baseField,
                unsupported,
                &ruleError
            );

        if (!rule) {
            if (error) {
                NSMutableDictionary *userInfo =
                    [ruleError.userInfo mutableCopy]
                        ?: [NSMutableDictionary dictionary];

                userInfo[
                    NTYTRuleParserErrorRuleIndexKey
                ] = @(i);

                *error =
                    [NSError errorWithDomain:
                        ruleError.domain
                        code:ruleError.code
                        userInfo:userInfo];
            }
            return nil;
        }

        [rules addObject:rule];
    }

    return [[NTYTRuleParserResult alloc]
        initWithRules:rules
        unsupportedModifiers:unsupported.array];
}

@end
