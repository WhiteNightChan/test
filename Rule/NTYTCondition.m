#import "NTYTCondition.h"

static NSError *NTYTConditionError(
    NTYTRuleModelErrorCode code,
    NSString *description
) {
    return [NSError errorWithDomain:NTYTRuleModelErrorDomain
                               code:code
                           userInfo:@{
                               NSLocalizedDescriptionKey:
                                   description ?: @"Invalid rule condition."
                           }];
}

static BOOL NTYTValueIsValidForMatcher(
    id value,
    NTYTMatcher matcher
) {
    switch (matcher) {
        case NTYTMatcherContains:
        case NTYTMatcherExact:
        case NTYTMatcherRegex:
            return [value isKindOfClass:[NSString class]];

        case NTYTMatcherBoolean:
        case NTYTMatcherLessThan:
        case NTYTMatcherLessThanOrEqual:
        case NTYTMatcherGreaterThan:
        case NTYTMatcherGreaterThanOrEqual:
            return [value isKindOfClass:[NSNumber class]];

        case NTYTMatcherUnknown:
        default:
            return NO;
    }
}

@implementation NTYTCondition

- (instancetype)initWithField:(NTYTField)field
                      matcher:(NTYTMatcher)matcher
                        value:(id<NSCopying>)value
                      negated:(BOOL)negated
        caseSensitiveOverride:(NTYTOptionOverride)caseSensitiveOverride
           exactMatchOverride:(NTYTOptionOverride)exactMatchOverride
         wordBoundaryOverride:(NTYTOptionOverride)wordBoundaryOverride {
    return [self initWithField:field
                       matcher:matcher
                         value:value
                    regexFlags:nil
                       negated:negated
         caseSensitiveOverride:caseSensitiveOverride
            exactMatchOverride:exactMatchOverride
          wordBoundaryOverride:wordBoundaryOverride];
}

- (instancetype)initWithField:(NTYTField)field
                      matcher:(NTYTMatcher)matcher
                        value:(id<NSCopying>)value
                   regexFlags:(NSString *)regexFlags
                      negated:(BOOL)negated
        caseSensitiveOverride:(NTYTOptionOverride)caseSensitiveOverride
           exactMatchOverride:(NTYTOptionOverride)exactMatchOverride
         wordBoundaryOverride:(NTYTOptionOverride)wordBoundaryOverride {
    self = [super init];

    if (self) {
        _field = field;
        _matcher = matcher;
        _value = [value copyWithZone:nil];
        _regexFlags = [regexFlags copy];
        _negated = negated;
        _caseSensitiveOverride = caseSensitiveOverride;
        _exactMatchOverride = exactMatchOverride;
        _wordBoundaryOverride = wordBoundaryOverride;
    }

    return self;
}

+ (instancetype)conditionFromDictionary:(NSDictionary *)dictionary
                                   error:(NSError **)error {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = NTYTConditionError(
                NTYTRuleModelErrorInvalidDictionary,
                @"Condition must be an NSDictionary."
            );
        }
        return nil;
    }

    NSString *fieldString = dictionary[@"field"];
    NSString *matcherString = dictionary[@"matcher"];
    id value = dictionary[@"value"];

    NTYTField field = NTYTFieldFromString(fieldString);
    if (field == NTYTFieldUnknown) {
        if (error) {
            *error = NTYTConditionError(
                NTYTRuleModelErrorInvalidField,
                @"Condition contains an unknown or missing field."
            );
        }
        return nil;
    }

    NTYTMatcher matcher = NTYTMatcherFromString(matcherString);
    if (matcher == NTYTMatcherUnknown) {
        if (error) {
            *error = NTYTConditionError(
                NTYTRuleModelErrorInvalidMatcher,
                @"Condition contains an unknown or missing matcher."
            );
        }
        return nil;
    }

    if (!value || value == [NSNull null]) {
        if (error) {
            *error = NTYTConditionError(
                NTYTRuleModelErrorMissingRequiredValue,
                @"Condition is missing its value."
            );
        }
        return nil;
    }

    if (![value conformsToProtocol:@protocol(NSCopying)] ||
        !NTYTValueIsValidForMatcher(value, matcher)) {
        if (error) {
            *error = NTYTConditionError(
                NTYTRuleModelErrorInvalidValueType,
                @"Condition value type does not match its matcher."
            );
        }
        return nil;
    }

    id regexFlagsObject = dictionary[@"regexFlags"];
    NSString *regexFlags = nil;
    if (regexFlagsObject && regexFlagsObject != [NSNull null]) {
        if (![regexFlagsObject isKindOfClass:[NSString class]]) {
            if (error) {
                *error = NTYTConditionError(
                    NTYTRuleModelErrorInvalidValueType,
                    @"regexFlags must be a string or null."
                );
            }
            return nil;
        }
        regexFlags = (NSString *)regexFlagsObject;
    }

    BOOL negated = [dictionary[@"negated"] boolValue];

    NSDictionary *options = dictionary[@"options"];
    if (options && ![options isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = NTYTConditionError(
                NTYTRuleModelErrorInvalidDictionary,
                @"Condition options must be an NSDictionary."
            );
        }
        return nil;
    }

    NTYTOptionOverride caseSensitive =
        NTYTOptionOverrideInherit;
    NTYTOptionOverride exactMatch =
        NTYTOptionOverrideInherit;
    NTYTOptionOverride wordBoundary =
        NTYTOptionOverrideInherit;

    if (!NTYTOptionOverrideFromObject(
            options[@"caseSensitive"],
            &caseSensitive
        ) ||
        !NTYTOptionOverrideFromObject(
            options[@"exactMatch"],
            &exactMatch
        ) ||
        !NTYTOptionOverrideFromObject(
            options[@"wordBoundary"],
            &wordBoundary
        )) {
        if (error) {
            *error = NTYTConditionError(
                NTYTRuleModelErrorInvalidOptionOverride,
                @"Condition contains an invalid option override."
            );
        }
        return nil;
    }

    return [[self alloc]
        initWithField:field
        matcher:matcher
        value:(id<NSCopying>)value
        regexFlags:regexFlags
        negated:negated
        caseSensitiveOverride:caseSensitive
        exactMatchOverride:exactMatch
        wordBoundaryOverride:wordBoundary];
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dictionary = [@{
        @"field": NTYTStringFromField(self.field),
        @"matcher": NTYTStringFromMatcher(self.matcher),
        @"value": self.value,
        @"negated": @(self.negated),
        @"options": @{
            @"caseSensitive":
                NTYTStringFromOptionOverride(
                    self.caseSensitiveOverride
                ),
            @"exactMatch":
                NTYTStringFromOptionOverride(
                    self.exactMatchOverride
                ),
            @"wordBoundary":
                NTYTStringFromOptionOverride(
                    self.wordBoundaryOverride
                ),
        },
    } mutableCopy];

    if (self.regexFlags.length > 0) {
        dictionary[@"regexFlags"] = self.regexFlags;
    }

    return [dictionary copy];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

@end
