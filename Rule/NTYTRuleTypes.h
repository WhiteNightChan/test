#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const NTYTRuleModelErrorDomain;

typedef NS_ERROR_ENUM(NTYTRuleModelErrorDomain, NTYTRuleModelErrorCode) {
    NTYTRuleModelErrorInvalidDictionary = 1,
    NTYTRuleModelErrorMissingRequiredValue,
    NTYTRuleModelErrorInvalidField,
    NTYTRuleModelErrorInvalidMatcher,
    NTYTRuleModelErrorInvalidOptionOverride,
    NTYTRuleModelErrorInvalidValueType,
    NTYTRuleModelErrorInvalidPredicates,
    NTYTRuleModelErrorUnsupportedCombinator,
};

typedef NS_ENUM(NSInteger, NTYTField) {
    NTYTFieldUnknown = 0,

    NTYTFieldGeneralText,
    NTYTFieldContentText,
    NTYTFieldVideoText,
    NTYTFieldVideoID,
    NTYTFieldChannelIdentity,

    // Special / future-provider fields.
    NTYTFieldViewCount,
    NTYTFieldDescription,
    NTYTFieldTags,
    NTYTFieldIsLive,
    NTYTFieldIsMember,
};

typedef NS_ENUM(NSInteger, NTYTMatcher) {
    NTYTMatcherUnknown = 0,

    NTYTMatcherContains,
    NTYTMatcherExact,
    NTYTMatcherRegex,
    NTYTMatcherBoolean,

    // Reserved for explicit numeric predicates such as view_count.
    NTYTMatcherLessThan,
    NTYTMatcherLessThanOrEqual,
    NTYTMatcherGreaterThan,
    NTYTMatcherGreaterThanOrEqual,
};

typedef NS_ENUM(NSInteger, NTYTOptionOverride) {
    NTYTOptionOverrideInherit = 0,
    NTYTOptionOverrideForceOn,
    NTYTOptionOverrideForceOff,
};

typedef NS_ENUM(NSInteger, NTYTMatchResult) {
    NTYTMatchResultNoMatch = 0,
    NTYTMatchResultMatch,
    NTYTMatchResultUnknown,
};

FOUNDATION_EXPORT NSString *NTYTStringFromField(NTYTField field);
FOUNDATION_EXPORT NTYTField NTYTFieldFromString(NSString *string);

FOUNDATION_EXPORT NSString *NTYTStringFromMatcher(NTYTMatcher matcher);
FOUNDATION_EXPORT NTYTMatcher NTYTMatcherFromString(NSString *string);

FOUNDATION_EXPORT NSString *NTYTStringFromOptionOverride(NTYTOptionOverride value);
FOUNDATION_EXPORT BOOL NTYTOptionOverrideFromObject(
    id _Nullable object,
    NTYTOptionOverride *outValue
);

NS_ASSUME_NONNULL_END
