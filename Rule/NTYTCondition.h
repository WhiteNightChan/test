#import <Foundation/Foundation.h>

#import "NTYTRuleTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface NTYTCondition : NSObject <NSCopying>

@property (nonatomic, readonly) NTYTField field;
@property (nonatomic, readonly) NTYTMatcher matcher;
@property (nonatomic, copy, readonly) id<NSCopying> value;
@property (nonatomic, copy, readonly, nullable) NSString *regexFlags;
@property (nonatomic, readonly, getter=isNegated) BOOL negated;

@property (nonatomic, readonly) NTYTOptionOverride caseSensitiveOverride;
@property (nonatomic, readonly) NTYTOptionOverride exactMatchOverride;
@property (nonatomic, readonly) NTYTOptionOverride wordBoundaryOverride;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

// Phase 1-compatible initializer. Regex flags default to nil.
- (instancetype)initWithField:(NTYTField)field
                      matcher:(NTYTMatcher)matcher
                        value:(id<NSCopying>)value
                      negated:(BOOL)negated
        caseSensitiveOverride:(NTYTOptionOverride)caseSensitiveOverride
           exactMatchOverride:(NTYTOptionOverride)exactMatchOverride
         wordBoundaryOverride:(NTYTOptionOverride)wordBoundaryOverride;

- (instancetype)initWithField:(NTYTField)field
                      matcher:(NTYTMatcher)matcher
                        value:(id<NSCopying>)value
                   regexFlags:(nullable NSString *)regexFlags
                      negated:(BOOL)negated
        caseSensitiveOverride:(NTYTOptionOverride)caseSensitiveOverride
           exactMatchOverride:(NTYTOptionOverride)exactMatchOverride
         wordBoundaryOverride:(NTYTOptionOverride)wordBoundaryOverride
    NS_DESIGNATED_INITIALIZER;

+ (nullable instancetype)conditionFromDictionary:(NSDictionary *)dictionary
                                           error:(NSError * _Nullable * _Nullable)error;

- (NSDictionary *)dictionaryRepresentation;

@end

NS_ASSUME_NONNULL_END
