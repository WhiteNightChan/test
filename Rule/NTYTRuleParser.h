#import <Foundation/Foundation.h>

#import "NTYTRule.h"
#import "NTYTRuleTypes.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const NTYTRuleParserErrorDomain;
FOUNDATION_EXPORT NSString * const NTYTRuleParserErrorOffsetKey;
FOUNDATION_EXPORT NSString * const NTYTRuleParserErrorRuleIndexKey;

typedef NS_ERROR_ENUM(NTYTRuleParserErrorDomain, NTYTRuleParserErrorCode) {
    NTYTRuleParserErrorInvalidArgument = 1,
    NTYTRuleParserErrorInvalidBaseField,
    NTYTRuleParserErrorUnterminatedRegex,
    NTYTRuleParserErrorInvalidRegexLiteral,
    NTYTRuleParserErrorUnterminatedModifier,
    NTYTRuleParserErrorInvalidModifier,
    NTYTRuleParserErrorMissingModifierValue,
    NTYTRuleParserErrorUnexpectedModifierValue,
    NTYTRuleParserErrorMissingKeyword,
    NTYTRuleParserErrorEmptyAndOperand,
    NTYTRuleParserErrorModelBuildFailed,
};

typedef NS_OPTIONS(NSUInteger, NTYTRuleParserSeparators) {
    NTYTRuleParserSeparatorNone    = 0,
    NTYTRuleParserSeparatorComma   = 1 << 0,
    NTYTRuleParserSeparatorNewline = 1 << 1,

    NTYTRuleParserSeparatorDefault =
        NTYTRuleParserSeparatorComma |
        NTYTRuleParserSeparatorNewline,
};

@interface NTYTRuleParserResult : NSObject

@property (nonatomic, copy, readonly) NSArray<NTYTRule *> *rules;

// Normalized modifier names that were syntactically accepted but compiled
// into NTYTFieldUnsupported. Their predicates evaluate to UNKNOWN.
@property (nonatomic, copy, readonly) NSArray<NSString *> *unsupportedModifiers;

@end

@interface NTYTRuleParser : NSObject

// Convenience entry point used by General / Videos / Channels text areas.
// Comma and newline are both treated as top-level rule separators.
// A backslash before a comma or newline keeps it inside the keyword.
+ (nullable NTYTRuleParserResult *)parseSource:(NSString *)source
                                 sourceSection:(NSString *)sourceSection
                                     baseField:(NTYTField)baseField
                              identifierPrefix:(nullable NSString *)identifierPrefix
                                         error:(NSError * _Nullable * _Nullable)error;

// Same parser with explicit top-level separators.
+ (nullable NTYTRuleParserResult *)parseSource:(NSString *)source
                                 sourceSection:(NSString *)sourceSection
                                     baseField:(NTYTField)baseField
                              identifierPrefix:(nullable NSString *)identifierPrefix
                                    separators:(NTYTRuleParserSeparators)separators
                                         error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
