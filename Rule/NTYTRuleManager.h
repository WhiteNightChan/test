#import <Foundation/Foundation.h>

#import "NTYTRule.h"
#import "NTYTRuleEvaluationOptions.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const NTYTRuleManagerErrorDomain;
FOUNDATION_EXPORT NSString * const NTYTRuleManagerPreferencesDomain;
FOUNDATION_EXPORT NSInteger const NTYTRuleManagerCurrentSchemaVersion;

typedef NS_ERROR_ENUM(NTYTRuleManagerErrorDomain, NTYTRuleManagerErrorCode) {
    NTYTRuleManagerErrorInvalidPersistentStore = 1,
    NTYTRuleManagerErrorUnsupportedSchemaVersion,
    NTYTRuleManagerErrorRuleDecodeFailed,
    NTYTRuleManagerErrorInvalidGroupState,
    NTYTRuleManagerErrorInvalidSectionOptions,
    NTYTRuleManagerErrorInvalidSaveInput,
    NTYTRuleManagerErrorSynchronizeFailed,
    NTYTRuleManagerErrorBootstrapFailed,
};

@interface NTYTRuleManager : NSObject

@property (nonatomic, readonly) NSInteger schemaVersion;

// Complete persisted rule lists. Disabled groups are still present here so
// Phase 6 UI can edit them without losing data.
@property (nonatomic, copy, readonly) NSArray<NTYTRule *> *allowRules;
@property (nonatomic, copy, readonly) NSArray<NTYTRule *> *blockRules;

// Runtime lists after group-level enable/disable is applied.
@property (nonatomic, copy, readonly) NSArray<NTYTRule *> *effectiveAllowRules;
@property (nonatomic, copy, readonly) NSArray<NTYTRule *> *effectiveBlockRules;

// group id -> @YES/@NO. A group absent from this dictionary is enabled.
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSNumber *> *groupStates;

@property (nonatomic, copy, readonly)
    NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *defaultOptionsBySection;

+ (instancetype)sharedManager;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

// Re-read com.whitenightchan.nothankyoutube from CFPreferences and rebuild
// the in-memory runtime cache. If the domain does not exist yet, the current
// Phase 4 smoke-test rule ("自作PC") is written once as the initial store.
- (BOOL)reloadWithError:(NSError * _Nullable * _Nullable)error;

// Phase 6 UI will use this API. Input is validated, serialized, synchronized
// to the dedicated preference domain, then the runtime cache is swapped.
- (BOOL)replaceAllowRules:(NSArray<NTYTRule *> *)allowRules
               blockRules:(NSArray<NTYTRule *> *)blockRules
               groupStates:(NSDictionary<NSString *, NSNumber *> *)groupStates
   defaultOptionsBySection:
       (NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *)defaultOptionsBySection
                     error:(NSError * _Nullable * _Nullable)error;

// Diagnostic/property-list form of the current cache. This is a copy and can
// be logged/inspected safely without mutating the manager.
- (NSDictionary *)persistentDictionaryRepresentation;

@end

NS_ASSUME_NONNULL_END
