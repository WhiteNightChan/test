#import <Foundation/Foundation.h>

#import "NTYTRule.h"
#import "NTYTRuleEvaluationContext.h"
#import "NTYTRuleEvaluationOptions.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const NTYTRuleEvaluatorErrorDomain;

typedef NS_ERROR_ENUM(NTYTRuleEvaluatorErrorDomain, NTYTRuleEvaluatorErrorCode) {
    NTYTRuleEvaluatorErrorInvalidRegex = 1,
    NTYTRuleEvaluatorErrorUnsupportedRegexFlag,
    NTYTRuleEvaluatorErrorInvalidConditionValue,
};

@interface NTYTRuleEvaluator : NSObject

// Evaluates one rule. Rule predicates are ANDed.
// Disabled rules return NO_MATCH.
+ (NTYTMatchResult)evaluateRule:(NTYTRule *)rule
                        context:(NTYTRuleEvaluationContext *)context
                 defaultOptions:(NTYTRuleEvaluationOptions *)defaultOptions
                          error:(NSError * _Nullable * _Nullable)error;

// Evaluates an OR-list of rules. The first MATCH wins.
// If there is no MATCH but at least one UNKNOWN, returns UNKNOWN.
+ (NTYTMatchResult)evaluateAnyRule:(NSArray<NTYTRule *> *)rules
                           context:(NTYTRuleEvaluationContext *)context
          defaultOptionsBySection:
              (NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *)
                  defaultOptionsBySection;

// Global policy:
// 1) any allow MATCH => PASS
// 2) otherwise any block MATCH => BLOCK
// 3) UNKNOWN never causes blocking and never counts as allow MATCH
+ (BOOL)shouldBlockContext:(NTYTRuleEvaluationContext *)context
                allowRules:(NSArray<NTYTRule *> *)allowRules
                blockRules:(NSArray<NTYTRule *> *)blockRules
   defaultOptionsBySection:
       (NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *)
           defaultOptionsBySection;

@end

NS_ASSUME_NONNULL_END
