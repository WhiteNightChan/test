#import <Foundation/Foundation.h>

#import "NTYTCondition.h"
#import "NTYTRuleTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface NTYTRule : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;

@property (nonatomic, copy, readonly, nullable) NSString *group;
@property (nonatomic, copy, readonly) NSString *sourceSection;
@property (nonatomic, readonly) NTYTField baseField;
@property (nonatomic, copy, readonly, nullable) NSString *sourceText;

@property (nonatomic, copy, readonly) NSArray<NTYTCondition *> *predicates;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithIdentifier:(NSString *)identifier
                           enabled:(BOOL)enabled
                             group:(nullable NSString *)group
                     sourceSection:(NSString *)sourceSection
                         baseField:(NTYTField)baseField
                        sourceText:(nullable NSString *)sourceText
                        predicates:(NSArray<NTYTCondition *> *)predicates
    NS_DESIGNATED_INITIALIZER;

+ (nullable instancetype)ruleFromDictionary:(NSDictionary *)dictionary
                                      error:(NSError * _Nullable * _Nullable)error;

- (NSDictionary *)dictionaryRepresentation;

@end

NS_ASSUME_NONNULL_END
