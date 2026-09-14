#import "NTYTRuleManager.h"

#import <CoreFoundation/CoreFoundation.h>

#import "NTYTRuleParser.h"
#import "../NTYTLogHelper.h"

NSErrorDomain const NTYTRuleManagerErrorDomain = @"NTYTRuleManagerErrorDomain";
NSString * const NTYTRuleManagerPreferencesDomain = @"com.whitenightchan.nothankyoutube";
NSInteger const NTYTRuleManagerCurrentSchemaVersion = 1;

static NSString * const NTYTKeySchemaVersion = @"schemaVersion";
static NSString * const NTYTKeyAllowRules = @"allowRules";
static NSString * const NTYTKeyBlockRules = @"blockRules";
static NSString * const NTYTKeyGroups = @"groups";
static NSString * const NTYTKeySectionOptions = @"sectionOptions";

@interface NTYTRuleManager ()

- (instancetype)initPrivate;

@property (nonatomic, readwrite) NSInteger schemaVersion;
@property (nonatomic, copy, readwrite) NSArray<NTYTRule *> *allowRules;
@property (nonatomic, copy, readwrite) NSArray<NTYTRule *> *blockRules;
@property (nonatomic, copy, readwrite) NSArray<NTYTRule *> *effectiveAllowRules;
@property (nonatomic, copy, readwrite) NSArray<NTYTRule *> *effectiveBlockRules;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSNumber *> *groupStates;
@property (nonatomic, copy, readwrite)
    NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *defaultOptionsBySection;

@end

static NSError *NTYTRuleManagerError(
    NTYTRuleManagerErrorCode code,
    NSString *description
) {
    return [NSError errorWithDomain:NTYTRuleManagerErrorDomain
                               code:code
                           userInfo:@{
                               NSLocalizedDescriptionKey:
                                   description ?: @"Rule manager error."
                           }];
}

static CFStringRef NTYTPreferencesAppID(void) {
    return (__bridge CFStringRef)NTYTRuleManagerPreferencesDomain;
}

static NSArray<NSString *> *NTYTPreferenceKeys(void) {
    static NSArray<NSString *> *keys;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        keys = @[
            NTYTKeySchemaVersion,
            NTYTKeyAllowRules,
            NTYTKeyBlockRules,
            NTYTKeyGroups,
            NTYTKeySectionOptions,
        ];
    });

    return keys;
}

static NSDictionary *NTYTCopyPreferenceStore(void) {
    CFPreferencesSynchronize(
        NTYTPreferencesAppID(),
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost
    );

    CFDictionaryRef copied = CFPreferencesCopyMultiple(
        (__bridge CFArrayRef)NTYTPreferenceKeys(),
        NTYTPreferencesAppID(),
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost
    );

    if (!copied) {
        return @{};
    }

    NSDictionary *store = CFBridgingRelease(copied);
    return [store isKindOfClass:[NSDictionary class]] ? store : @{};
}

static BOOL NTYTWritePreferenceStore(NSDictionary *store) {
    CFPreferencesSetMultiple(
        (__bridge CFDictionaryRef)store,
        NULL,
        NTYTPreferencesAppID(),
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost
    );

    return CFPreferencesSynchronize(
        NTYTPreferencesAppID(),
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost
    );
}

static NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *
NTYTBootstrapSectionOptions(void) {
    return @{
        @"general.block":
            [NTYTRuleEvaluationOptions
                optionsWithCaseSensitive:NO
                exactMatch:NO
                wordBoundary:NO],
        @"general.allow":
            [NTYTRuleEvaluationOptions
                optionsWithCaseSensitive:NO
                exactMatch:NO
                wordBoundary:NO],

        @"videos.title.block":
            [NTYTRuleEvaluationOptions
                optionsWithCaseSensitive:NO
                exactMatch:NO
                wordBoundary:NO],
        @"videos.channel.block":
            [NTYTRuleEvaluationOptions
                optionsWithCaseSensitive:NO
                exactMatch:YES
                wordBoundary:NO],
        @"videos.id.block":
            [NTYTRuleEvaluationOptions
                optionsWithCaseSensitive:YES
                exactMatch:YES
                wordBoundary:NO],

        @"channels.block":
            [NTYTRuleEvaluationOptions
                optionsWithCaseSensitive:NO
                exactMatch:YES
                wordBoundary:NO],
        @"channels.allow":
            [NTYTRuleEvaluationOptions
                optionsWithCaseSensitive:NO
                exactMatch:YES
                wordBoundary:NO],

        @"custom.block":
            [NTYTRuleEvaluationOptions
                optionsWithCaseSensitive:NO
                exactMatch:NO
                wordBoundary:NO],
        @"custom.allow":
            [NTYTRuleEvaluationOptions
                optionsWithCaseSensitive:NO
                exactMatch:NO
                wordBoundary:NO],
    };
}

static NSDictionary *NTYTDictionaryFromOptions(
    NTYTRuleEvaluationOptions *options
) {
    return @{
        @"caseSensitive": @(options.caseSensitive),
        @"exactMatch": @(options.exactMatch),
        @"wordBoundary": @(options.wordBoundary),
    };
}


static BOOL NTYTValidateSectionOptionObjects(
    id object,
    NSError **error
) {
    if (![object isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = NTYTRuleManagerError(
                NTYTRuleManagerErrorInvalidSaveInput,
                @"defaultOptionsBySection must be an NSDictionary."
            );
        }
        return NO;
    }

    NSDictionary *dictionary = object;
    for (id key in dictionary) {
        id value = dictionary[key];
        if (![key isKindOfClass:[NSString class]] ||
            [(NSString *)key length] == 0 ||
            ![value isKindOfClass:[NTYTRuleEvaluationOptions class]]) {
            if (error) {
                *error = NTYTRuleManagerError(
                    NTYTRuleManagerErrorInvalidSaveInput,
                    @"defaultOptionsBySection contains an invalid entry."
                );
            }
            return NO;
        }
    }

    return YES;
}

static NSDictionary *NTYTEncodeSectionOptions(
    NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *optionsBySection
) {
    NSMutableDictionary *encoded = [NSMutableDictionary dictionary];

    [optionsBySection enumerateKeysAndObjectsUsingBlock:^(NSString *section,
                                                          NTYTRuleEvaluationOptions *options,
                                                          BOOL *stop) {
        encoded[section] = NTYTDictionaryFromOptions(options);
    }];

    return [encoded copy];
}

static NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *
NTYTDecodeSectionOptions(id object, NSError **error) {
    if (![object isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = NTYTRuleManagerError(
                NTYTRuleManagerErrorInvalidSectionOptions,
                @"sectionOptions must be an NSDictionary."
            );
        }
        return nil;
    }

    NSDictionary *dictionary = object;
    NSMutableDictionary<NSString *, NTYTRuleEvaluationOptions *> *decoded =
        [NSMutableDictionary dictionaryWithCapacity:dictionary.count];

    for (id key in dictionary) {
        id value = dictionary[key];

        if (![key isKindOfClass:[NSString class]] ||
            [(NSString *)key length] == 0 ||
            ![value isKindOfClass:[NSDictionary class]]) {
            if (error) {
                *error = NTYTRuleManagerError(
                    NTYTRuleManagerErrorInvalidSectionOptions,
                    @"sectionOptions contains an invalid section entry."
                );
            }
            return nil;
        }

        NSDictionary *optionDictionary = value;
        id caseSensitive = optionDictionary[@"caseSensitive"];
        id exactMatch = optionDictionary[@"exactMatch"];
        id wordBoundary = optionDictionary[@"wordBoundary"];

        if (![caseSensitive isKindOfClass:[NSNumber class]] ||
            ![exactMatch isKindOfClass:[NSNumber class]] ||
            ![wordBoundary isKindOfClass:[NSNumber class]]) {
            if (error) {
                *error = NTYTRuleManagerError(
                    NTYTRuleManagerErrorInvalidSectionOptions,
                    [NSString stringWithFormat:
                        @"sectionOptions[%@] must contain boolean NSNumber values.",
                        key]
                );
            }
            return nil;
        }

        decoded[key] =
            [NTYTRuleEvaluationOptions
                optionsWithCaseSensitive:[caseSensitive boolValue]
                exactMatch:[exactMatch boolValue]
                wordBoundary:[wordBoundary boolValue]];
    }

    return [decoded copy];
}

static NSArray<NSDictionary *> *NTYTEncodeRules(
    NSArray<NTYTRule *> *rules
) {
    NSMutableArray<NSDictionary *> *encoded =
        [NSMutableArray arrayWithCapacity:rules.count];

    for (NTYTRule *rule in rules) {
        [encoded addObject:[rule dictionaryRepresentation]];
    }

    return [encoded copy];
}

static NSArray<NTYTRule *> *NTYTDecodeRules(
    id object,
    NSString *listName,
    NSError **error
) {
    if (![object isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = NTYTRuleManagerError(
                NTYTRuleManagerErrorRuleDecodeFailed,
                [NSString stringWithFormat:
                    @"%@ must be an NSArray.",
                    listName]
            );
        }
        return nil;
    }

    NSArray *encodedRules = object;
    NSMutableArray<NTYTRule *> *rules =
        [NSMutableArray arrayWithCapacity:encodedRules.count];
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];

    for (id item in encodedRules) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            if (error) {
                *error = NTYTRuleManagerError(
                    NTYTRuleManagerErrorRuleDecodeFailed,
                    [NSString stringWithFormat:
                        @"%@ contains a non-dictionary rule.",
                        listName]
                );
            }
            return nil;
        }

        NSError *ruleError = nil;
        NTYTRule *rule = [NTYTRule ruleFromDictionary:item error:&ruleError];
        if (!rule) {
            if (error) {
                *error = ruleError ?: NTYTRuleManagerError(
                    NTYTRuleManagerErrorRuleDecodeFailed,
                    [NSString stringWithFormat:
                        @"%@ contains an invalid rule.",
                        listName]
                );
            }
            return nil;
        }

        if ([identifiers containsObject:rule.identifier]) {
            if (error) {
                *error = NTYTRuleManagerError(
                    NTYTRuleManagerErrorRuleDecodeFailed,
                    [NSString stringWithFormat:
                        @"%@ contains duplicate rule id %@.",
                        listName,
                        rule.identifier]
                );
            }
            return nil;
        }

        [identifiers addObject:rule.identifier];
        [rules addObject:rule];
    }

    return [rules copy];
}

static NSDictionary<NSString *, NSNumber *> *NTYTDecodeGroupStates(
    id object,
    NSError **error
) {
    if (![object isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = NTYTRuleManagerError(
                NTYTRuleManagerErrorInvalidGroupState,
                @"groups must be an NSDictionary."
            );
        }
        return nil;
    }

    NSMutableDictionary<NSString *, NSNumber *> *groups =
        [NSMutableDictionary dictionary];

    [(NSDictionary *)object enumerateKeysAndObjectsUsingBlock:^(id key,
                                                                 id value,
                                                                 BOOL *stop) {
        if (![key isKindOfClass:[NSString class]] ||
            [(NSString *)key length] == 0 ||
            ![value isKindOfClass:[NSNumber class]]) {
            *stop = YES;
            return;
        }

        groups[key] = @([value boolValue]);
    }];

    if (groups.count != [(NSDictionary *)object count]) {
        if (error) {
            *error = NTYTRuleManagerError(
                NTYTRuleManagerErrorInvalidGroupState,
                @"groups contains an invalid key or value."
            );
        }
        return nil;
    }

    return [groups copy];
}

static NSArray<NTYTRule *> *NTYTEffectiveRules(
    NSArray<NTYTRule *> *rules,
    NSDictionary<NSString *, NSNumber *> *groupStates
) {
    NSMutableArray<NTYTRule *> *effective =
        [NSMutableArray arrayWithCapacity:rules.count];

    for (NTYTRule *rule in rules) {
        if (rule.group.length > 0) {
            NSNumber *enabled = groupStates[rule.group];
            if (enabled && !enabled.boolValue) {
                continue;
            }
        }

        [effective addObject:rule];
    }

    return [effective copy];
}

static BOOL NTYTValidateRuleObjects(
    NSArray<NTYTRule *> *allowRules,
    NSArray<NTYTRule *> *blockRules,
    NSError **error
) {
    if (![allowRules isKindOfClass:[NSArray class]] ||
        ![blockRules isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = NTYTRuleManagerError(
                NTYTRuleManagerErrorInvalidSaveInput,
                @"allowRules and blockRules must be arrays."
            );
        }
        return NO;
    }

    NSMutableSet<NSString *> *allIdentifiers = [NSMutableSet set];

    for (NSArray<NTYTRule *> *rules in @[allowRules, blockRules]) {
        for (id object in rules) {
            if (![object isKindOfClass:[NTYTRule class]]) {
                if (error) {
                    *error = NTYTRuleManagerError(
                        NTYTRuleManagerErrorInvalidSaveInput,
                        @"Rule arrays may contain only NTYTRule objects."
                    );
                }
                return NO;
            }

            NTYTRule *rule = object;
            if ([allIdentifiers containsObject:rule.identifier]) {
                if (error) {
                    *error = NTYTRuleManagerError(
                        NTYTRuleManagerErrorInvalidSaveInput,
                        [NSString stringWithFormat:
                            @"Duplicate rule id across allow/block lists: %@.",
                            rule.identifier]
                    );
                }
                return NO;
            }

            [allIdentifiers addObject:rule.identifier];
        }
    }

    return YES;
}

@implementation NTYTRuleManager

+ (instancetype)sharedManager {
    static NTYTRuleManager *manager;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        manager = [[self alloc] initPrivate];
    });

    return manager;
}

- (instancetype)initPrivate {
    self = [super init];

    if (self) {
        _schemaVersion = NTYTRuleManagerCurrentSchemaVersion;
        _allowRules = @[];
        _blockRules = @[];
        _effectiveAllowRules = @[];
        _effectiveBlockRules = @[];
        _groupStates = @{};
        _defaultOptionsBySection = NTYTBootstrapSectionOptions();

        NSError *error = nil;
        if (![self reloadWithError:&error]) {
            NTYTLog(
                @"[NTYT][RuleManager] load failed; fail-safe PASS domain=%@ error=%@",
                NTYTRuleManagerPreferencesDomain,
                error
            );
        }
    }

    return self;
}

- (void)applyAllowRules:(NSArray<NTYTRule *> *)allowRules
             blockRules:(NSArray<NTYTRule *> *)blockRules
             groupStates:(NSDictionary<NSString *, NSNumber *> *)groupStates
 defaultOptionsBySection:
     (NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *)defaultOptionsBySection {
    self.schemaVersion = NTYTRuleManagerCurrentSchemaVersion;
    self.allowRules = allowRules;
    self.blockRules = blockRules;
    self.groupStates = groupStates;
    self.defaultOptionsBySection = defaultOptionsBySection;
    self.effectiveAllowRules = NTYTEffectiveRules(allowRules, groupStates);
    self.effectiveBlockRules = NTYTEffectiveRules(blockRules, groupStates);
}

- (void)applyFailSafeEmptyCache {
    [self applyAllowRules:@[]
               blockRules:@[]
               groupStates:@{}
   defaultOptionsBySection:NTYTBootstrapSectionOptions()];
}

- (BOOL)bootstrapWithError:(NSError **)error {
    NSError *parserError = nil;
    NTYTRuleParserResult *result =
        [NTYTRuleParser
            parseSource:@"自作PC"
            sourceSection:@"general.block"
            baseField:NTYTFieldGeneralText
            identifierPrefix:@"bootstrap.general.block"
            error:&parserError];

    if (!result) {
        if (error) {
            *error = parserError ?: NTYTRuleManagerError(
                NTYTRuleManagerErrorBootstrapFailed,
                @"Failed to compile the Phase 5 bootstrap rule."
            );
        }
        [self applyFailSafeEmptyCache];
        return NO;
    }

    BOOL saved = [self replaceAllowRules:@[]
                              blockRules:result.rules
                              groupStates:@{}
                  defaultOptionsBySection:NTYTBootstrapSectionOptions()
                                    error:error];

    if (saved) {
        NTYTLog(
            @"[NTYT][RuleManager] initialized dedicated preferences domain=%@ schema=%ld allow=%lu block=%lu",
            NTYTRuleManagerPreferencesDomain,
            (long)NTYTRuleManagerCurrentSchemaVersion,
            (unsigned long)self.allowRules.count,
            (unsigned long)self.blockRules.count
        );
    }

    return saved;
}

- (BOOL)reloadWithError:(NSError **)error {
    @synchronized (self) {
        NSDictionary *store = NTYTCopyPreferenceStore();

        BOOL hasAnyKnownKey = NO;
        for (NSString *key in NTYTPreferenceKeys()) {
            if (store[key] != nil) {
                hasAnyKnownKey = YES;
                break;
            }
        }

        if (!hasAnyKnownKey) {
            return [self bootstrapWithError:error];
        }

        id schemaObject = store[NTYTKeySchemaVersion];
        if (![schemaObject isKindOfClass:[NSNumber class]]) {
            [self applyFailSafeEmptyCache];
            if (error) {
                *error = NTYTRuleManagerError(
                    NTYTRuleManagerErrorInvalidPersistentStore,
                    @"Persisted rule store has no valid schemaVersion."
                );
            }
            return NO;
        }

        NSInteger schemaVersion = [schemaObject integerValue];
        if (schemaVersion != NTYTRuleManagerCurrentSchemaVersion) {
            [self applyFailSafeEmptyCache];
            if (error) {
                *error = NTYTRuleManagerError(
                    NTYTRuleManagerErrorUnsupportedSchemaVersion,
                    [NSString stringWithFormat:
                        @"Unsupported persisted schemaVersion %ld (current %ld).",
                        (long)schemaVersion,
                        (long)NTYTRuleManagerCurrentSchemaVersion]
                );
            }
            return NO;
        }

        NSError *decodeError = nil;
        NSArray<NTYTRule *> *allowRules =
            NTYTDecodeRules(store[NTYTKeyAllowRules], @"allowRules", &decodeError);
        if (!allowRules) {
            [self applyFailSafeEmptyCache];
            if (error) *error = decodeError;
            return NO;
        }

        NSArray<NTYTRule *> *blockRules =
            NTYTDecodeRules(store[NTYTKeyBlockRules], @"blockRules", &decodeError);
        if (!blockRules) {
            [self applyFailSafeEmptyCache];
            if (error) *error = decodeError;
            return NO;
        }

        NSMutableSet<NSString *> *allIdentifiers = [NSMutableSet set];
        for (NTYTRule *rule in allowRules) {
            [allIdentifiers addObject:rule.identifier];
        }
        for (NTYTRule *rule in blockRules) {
            if ([allIdentifiers containsObject:rule.identifier]) {
                [self applyFailSafeEmptyCache];
                if (error) {
                    *error = NTYTRuleManagerError(
                        NTYTRuleManagerErrorRuleDecodeFailed,
                        [NSString stringWithFormat:
                            @"Duplicate rule id across allow/block lists: %@.",
                            rule.identifier]
                    );
                }
                return NO;
            }
            [allIdentifiers addObject:rule.identifier];
        }

        NSDictionary<NSString *, NSNumber *> *groupStates =
            NTYTDecodeGroupStates(store[NTYTKeyGroups], &decodeError);
        if (!groupStates) {
            [self applyFailSafeEmptyCache];
            if (error) *error = decodeError;
            return NO;
        }

        NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *sectionOptions =
            NTYTDecodeSectionOptions(store[NTYTKeySectionOptions], &decodeError);
        if (!sectionOptions) {
            [self applyFailSafeEmptyCache];
            if (error) *error = decodeError;
            return NO;
        }

        // Phase 6 adds defaults for every UI section without changing schemaVersion.
        // Existing Phase 5 plists only contain general.block/general.allow, so merge
        // the persisted dictionary over the complete current defaults.
        NSMutableDictionary<NSString *, NTYTRuleEvaluationOptions *> *mergedOptions =
            [NTYTBootstrapSectionOptions() mutableCopy];
        [mergedOptions addEntriesFromDictionary:sectionOptions];
        sectionOptions = [mergedOptions copy];

        [self applyAllowRules:allowRules
                   blockRules:blockRules
                   groupStates:groupStates
       defaultOptionsBySection:sectionOptions];

        NTYTLog(
            @"[NTYT][RuleManager] loaded domain=%@ schema=%ld allow=%lu block=%lu effectiveAllow=%lu effectiveBlock=%lu groups=%lu",
            NTYTRuleManagerPreferencesDomain,
            (long)self.schemaVersion,
            (unsigned long)self.allowRules.count,
            (unsigned long)self.blockRules.count,
            (unsigned long)self.effectiveAllowRules.count,
            (unsigned long)self.effectiveBlockRules.count,
            (unsigned long)self.groupStates.count
        );

        return YES;
    }
}

- (BOOL)replaceAllowRules:(NSArray<NTYTRule *> *)allowRules
               blockRules:(NSArray<NTYTRule *> *)blockRules
               groupStates:(NSDictionary<NSString *, NSNumber *> *)groupStates
   defaultOptionsBySection:
       (NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *)defaultOptionsBySection
                     error:(NSError **)error {
    @synchronized (self) {
        if (!NTYTValidateRuleObjects(allowRules, blockRules, error)) {
            return NO;
        }

        NSError *validationError = nil;
        NSDictionary<NSString *, NSNumber *> *validatedGroups =
            NTYTDecodeGroupStates(groupStates, &validationError);
        if (!validatedGroups) {
            if (error) *error = validationError;
            return NO;
        }

        if (!NTYTValidateSectionOptionObjects(
                defaultOptionsBySection,
                &validationError
            )) {
            if (error) *error = validationError;
            return NO;
        }

        // Accept a partial options dictionary from future callers, but always
        // persist/apply the complete Phase 6 defaults so runtime evaluation
        // never loses section semantics in the current process.
        NSMutableDictionary<NSString *, NTYTRuleEvaluationOptions *> *completeOptions =
            [NTYTBootstrapSectionOptions() mutableCopy];
        [completeOptions addEntriesFromDictionary:defaultOptionsBySection];

        NSDictionary *encodedOptions =
            NTYTEncodeSectionOptions([completeOptions copy]);
        NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *validatedOptions =
            NTYTDecodeSectionOptions(encodedOptions, &validationError);
        if (!validatedOptions) {
            if (error) *error = validationError;
            return NO;
        }

        NSDictionary *store = @{
            NTYTKeySchemaVersion: @(NTYTRuleManagerCurrentSchemaVersion),
            NTYTKeyAllowRules: NTYTEncodeRules(allowRules),
            NTYTKeyBlockRules: NTYTEncodeRules(blockRules),
            NTYTKeyGroups: validatedGroups,
            NTYTKeySectionOptions: encodedOptions,
        };

        if (![NSPropertyListSerialization propertyList:store
                                      isValidForFormat:NSPropertyListBinaryFormat_v1_0]) {
            if (error) {
                *error = NTYTRuleManagerError(
                    NTYTRuleManagerErrorInvalidSaveInput,
                    @"Rule store contains a non-property-list value."
                );
            }
            return NO;
        }

        if (!NTYTWritePreferenceStore(store)) {
            if (error) {
                *error = NTYTRuleManagerError(
                    NTYTRuleManagerErrorSynchronizeFailed,
                    [NSString stringWithFormat:
                        @"CFPreferences synchronize failed for %@.",
                        NTYTRuleManagerPreferencesDomain]
                );
            }
            return NO;
        }

        [self applyAllowRules:[allowRules copy]
                   blockRules:[blockRules copy]
                   groupStates:validatedGroups
       defaultOptionsBySection:validatedOptions];

        NTYTLog(
            @"[NTYT][RuleManager] saved domain=%@ schema=%ld allow=%lu block=%lu groups=%lu",
            NTYTRuleManagerPreferencesDomain,
            (long)self.schemaVersion,
            (unsigned long)self.allowRules.count,
            (unsigned long)self.blockRules.count,
            (unsigned long)self.groupStates.count
        );

        return YES;
    }
}

- (NSDictionary *)persistentDictionaryRepresentation {
    @synchronized (self) {
        return @{
            NTYTKeySchemaVersion: @(self.schemaVersion),
            NTYTKeyAllowRules: NTYTEncodeRules(self.allowRules),
            NTYTKeyBlockRules: NTYTEncodeRules(self.blockRules),
            NTYTKeyGroups: self.groupStates ?: @{},
            NTYTKeySectionOptions:
                NTYTEncodeSectionOptions(self.defaultOptionsBySection ?: @{}),
        };
    }
}

@end
