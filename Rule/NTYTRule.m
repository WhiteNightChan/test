#import "NTYTRule.h"

static NSError *NTYTRuleError(
    NTYTRuleModelErrorCode code,
    NSString *description
) {
    return [NSError errorWithDomain:NTYTRuleModelErrorDomain
                               code:code
                           userInfo:@{
                               NSLocalizedDescriptionKey:
                                   description ?: @"Invalid rule."
                           }];
}

@implementation NTYTRule

- (instancetype)initWithIdentifier:(NSString *)identifier
                           enabled:(BOOL)enabled
                             group:(NSString *)group
                     sourceSection:(NSString *)sourceSection
                         baseField:(NTYTField)baseField
                        sourceText:(NSString *)sourceText
                        predicates:(NSArray<NTYTCondition *> *)predicates {
    self = [super init];

    if (self) {
        _identifier = [identifier copy];
        _enabled = enabled;
        _group = [group copy];
        _sourceSection = [sourceSection copy];
        _baseField = baseField;
        _sourceText = [sourceText copy];
        _predicates = [predicates copy];
    }

    return self;
}

+ (instancetype)ruleFromDictionary:(NSDictionary *)dictionary
                              error:(NSError **)error {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = NTYTRuleError(
                NTYTRuleModelErrorInvalidDictionary,
                @"Rule must be an NSDictionary."
            );
        }
        return nil;
    }

    NSString *identifier = dictionary[@"id"];
    if (![identifier isKindOfClass:[NSString class]] ||
        identifier.length == 0) {
        if (error) {
            *error = NTYTRuleError(
                NTYTRuleModelErrorMissingRequiredValue,
                @"Rule is missing a non-empty id."
            );
        }
        return nil;
    }

    NSString *sourceSection = dictionary[@"sourceSection"];
    if (![sourceSection isKindOfClass:[NSString class]] ||
        sourceSection.length == 0) {
        if (error) {
            *error = NTYTRuleError(
                NTYTRuleModelErrorMissingRequiredValue,
                @"Rule is missing a non-empty sourceSection."
            );
        }
        return nil;
    }

    NSString *combinator = dictionary[@"combinator"];
    if (combinator &&
        (![combinator isKindOfClass:[NSString class]] ||
         ![combinator isEqualToString:@"all"])) {
        if (error) {
            *error = NTYTRuleError(
                NTYTRuleModelErrorUnsupportedCombinator,
                @"v1 supports only combinator = all."
            );
        }
        return nil;
    }

    NSString *baseFieldString = dictionary[@"baseField"];
    NTYTField baseField = NTYTFieldFromString(baseFieldString);
    if (baseField == NTYTFieldUnknown) {
        if (error) {
            *error = NTYTRuleError(
                NTYTRuleModelErrorInvalidField,
                @"Rule contains an unknown or missing baseField."
            );
        }
        return nil;
    }

    id groupObject = dictionary[@"group"];
    NSString *group = nil;
    if (groupObject && groupObject != [NSNull null]) {
        if (![groupObject isKindOfClass:[NSString class]]) {
            if (error) {
                *error = NTYTRuleError(
                    NTYTRuleModelErrorInvalidValueType,
                    @"Rule group must be a string or null."
                );
            }
            return nil;
        }
        group = (NSString *)groupObject;
    }

    id sourceTextObject = dictionary[@"sourceText"];
    NSString *sourceText = nil;
    if (sourceTextObject && sourceTextObject != [NSNull null]) {
        if (![sourceTextObject isKindOfClass:[NSString class]]) {
            if (error) {
                *error = NTYTRuleError(
                    NTYTRuleModelErrorInvalidValueType,
                    @"Rule sourceText must be a string or null."
                );
            }
            return nil;
        }
        sourceText = (NSString *)sourceTextObject;
    }

    NSArray *predicateDictionaries = dictionary[@"predicates"];
    if (![predicateDictionaries isKindOfClass:[NSArray class]] ||
        predicateDictionaries.count == 0) {
        if (error) {
            *error = NTYTRuleError(
                NTYTRuleModelErrorInvalidPredicates,
                @"Rule must contain at least one predicate."
            );
        }
        return nil;
    }

    NSMutableArray<NTYTCondition *> *predicates =
        [NSMutableArray arrayWithCapacity:predicateDictionaries.count];

    for (id item in predicateDictionaries) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            if (error) {
                *error = NTYTRuleError(
                    NTYTRuleModelErrorInvalidPredicates,
                    @"Every predicate must be an NSDictionary."
                );
            }
            return nil;
        }

        NSError *conditionError = nil;
        NTYTCondition *condition =
            [NTYTCondition conditionFromDictionary:item
                                             error:&conditionError];

        if (!condition) {
            if (error) {
                *error = conditionError ?: NTYTRuleError(
                    NTYTRuleModelErrorInvalidPredicates,
                    @"Rule contains an invalid predicate."
                );
            }
            return nil;
        }

        [predicates addObject:condition];
    }

    BOOL enabled = dictionary[@"enabled"]
        ? [dictionary[@"enabled"] boolValue]
        : YES;

    return [[self alloc]
        initWithIdentifier:identifier
        enabled:enabled
        group:group
        sourceSection:sourceSection
        baseField:baseField
        sourceText:sourceText
        predicates:predicates];
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableArray<NSDictionary *> *predicateDictionaries =
        [NSMutableArray arrayWithCapacity:self.predicates.count];

    for (NTYTCondition *condition in self.predicates) {
        [predicateDictionaries addObject:
            [condition dictionaryRepresentation]];
    }

    NSMutableDictionary *dictionary = [@{
        @"id": self.identifier,
        @"enabled": @(self.enabled),
        @"sourceSection": self.sourceSection,
        @"baseField": NTYTStringFromField(self.baseField),
        @"combinator": @"all",
        @"predicates": predicateDictionaries,
    } mutableCopy];

    if (self.group) {
        dictionary[@"group"] = self.group;
    }

    if (self.sourceText) {
        dictionary[@"sourceText"] = self.sourceText;
    }

    return [dictionary copy];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

@end
