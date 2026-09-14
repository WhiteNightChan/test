#import "NTYTRuleListController.h"

#import "NTYTRuleEditorController.h"
#import "../Rule/NTYTRuleManager.h"
#import "../Rule/NTYTRuleTypes.h"

#import "../NTYTLogHelper.h"

typedef NS_ENUM(NSInteger, NTYTOptionKind) {
    NTYTOptionKindCaseSensitive = 0,
    NTYTOptionKindExactMatch,
    NTYTOptionKindWordBoundary,
};

@interface NTYTRuleBucket : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *sourceSection;
@property (nonatomic) NTYTField baseField;
@property (nonatomic) NTYTRuleEditorAction action;
@property (nonatomic, copy) NSArray<NSNumber *> *optionKinds;
@end

@implementation NTYTRuleBucket
@end

@interface NTYTRuleListController ()
@property (nonatomic) NTYTRuleListScope scope;
@property (nonatomic, copy) NSArray<NTYTRuleBucket *> *buckets;
@end

@implementation NTYTRuleListController

- (instancetype)initWithScope:(NTYTRuleListScope)scope {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (!self) return nil;

    _scope = scope;
    _buckets = [self bucketsForScope:scope];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    switch (self.scope) {
        case NTYTRuleListScopeGeneral: self.title = @"General"; break;
        case NTYTRuleListScopeVideos: self.title = @"Videos"; break;
        case NTYTRuleListScopeChannels: self.title = @"Channels"; break;
        case NTYTRuleListScopeCustomRules: self.title = @"Custom Rules"; break;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Bucket definitions

- (NTYTRuleBucket *)bucketWithTitle:(NSString *)title
                      sourceSection:(NSString *)sourceSection
                          baseField:(NTYTField)baseField
                             action:(NTYTRuleEditorAction)action
                        optionKinds:(NSArray<NSNumber *> *)optionKinds {
    NTYTRuleBucket *bucket = [NTYTRuleBucket new];
    bucket.title = title;
    bucket.sourceSection = sourceSection;
    bucket.baseField = baseField;
    bucket.action = action;
    bucket.optionKinds = optionKinds ?: @[];
    return bucket;
}

- (NSArray<NTYTRuleBucket *> *)bucketsForScope:(NTYTRuleListScope)scope {
    switch (scope) {
        case NTYTRuleListScopeGeneral:
            return @[
                [self bucketWithTitle:@"Block content that include"
                         sourceSection:@"general.block"
                             baseField:NTYTFieldGeneralText
                                action:NTYTRuleEditorActionBlock
                           optionKinds:@[@(NTYTOptionKindCaseSensitive), @(NTYTOptionKindWordBoundary)]],
                [self bucketWithTitle:@"Do not block content that include"
                         sourceSection:@"general.allow"
                             baseField:NTYTFieldGeneralText
                                action:NTYTRuleEditorActionAllow
                           optionKinds:@[@(NTYTOptionKindCaseSensitive), @(NTYTOptionKindWordBoundary)]],
            ];

        case NTYTRuleListScopeVideos:
            return @[
                [self bucketWithTitle:@"Block videos that title include"
                         sourceSection:@"videos.title.block"
                             baseField:NTYTFieldVideoText
                                action:NTYTRuleEditorActionBlock
                           optionKinds:@[@(NTYTOptionKindCaseSensitive), @(NTYTOptionKindWordBoundary)]],
                [self bucketWithTitle:@"Block videos from these channels"
                         sourceSection:@"videos.channel.block"
                             baseField:NTYTFieldChannelIdentity
                                action:NTYTRuleEditorActionBlock
                           optionKinds:@[@(NTYTOptionKindCaseSensitive), @(NTYTOptionKindExactMatch)]],
                [self bucketWithTitle:@"Block videos by ID"
                         sourceSection:@"videos.id.block"
                             baseField:NTYTFieldVideoID
                                action:NTYTRuleEditorActionBlock
                           optionKinds:@[]],
            ];

        case NTYTRuleListScopeChannels:
            return @[
                [self bucketWithTitle:@"Block any content from these channels"
                         sourceSection:@"channels.block"
                             baseField:NTYTFieldChannelIdentity
                                action:NTYTRuleEditorActionBlock
                           optionKinds:@[@(NTYTOptionKindCaseSensitive), @(NTYTOptionKindExactMatch)]],
                [self bucketWithTitle:@"Whitelist channels"
                         sourceSection:@"channels.allow"
                             baseField:NTYTFieldChannelIdentity
                                action:NTYTRuleEditorActionAllow
                           optionKinds:@[@(NTYTOptionKindCaseSensitive), @(NTYTOptionKindExactMatch)]],
            ];

        case NTYTRuleListScopeCustomRules:
            return @[
                [self bucketWithTitle:@"Block Rules"
                         sourceSection:@"custom.block"
                             baseField:NTYTFieldUnknown
                                action:NTYTRuleEditorActionBlock
                           optionKinds:@[]],
                [self bucketWithTitle:@"Allow / Whitelist Rules"
                         sourceSection:@"custom.allow"
                             baseField:NTYTFieldUnknown
                                action:NTYTRuleEditorActionAllow
                           optionKinds:@[]],
            ];
    }
}

#pragma mark - Data helpers

- (NTYTRuleManager *)manager {
    return [NTYTRuleManager sharedManager];
}

- (NSArray<NTYTRule *> *)rulesForBucket:(NTYTRuleBucket *)bucket {
    NSArray<NTYTRule *> *source =
        bucket.action == NTYTRuleEditorActionAllow
            ? self.manager.allowRules
            : self.manager.blockRules;

    NSMutableArray<NTYTRule *> *matches = [NSMutableArray array];
    for (NTYTRule *rule in source) {
        if ([rule.sourceSection isEqualToString:bucket.sourceSection]) {
            [matches addObject:rule];
        }
    }
    return [matches copy];
}

- (NSArray<NSString *> *)allGroupNames {
    NSMutableSet<NSString *> *groups = [NSMutableSet set];
    [groups addObjectsFromArray:self.manager.groupStates.allKeys];

    for (NTYTRule *rule in self.manager.allowRules) {
        if (rule.group.length > 0) [groups addObject:rule.group];
    }
    for (NTYTRule *rule in self.manager.blockRules) {
        if (rule.group.length > 0) [groups addObject:rule.group];
    }

    return [[groups allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (NSDictionary<NSString *, NSNumber *> *)prunedGroupStatesForAllowRules:(NSArray<NTYTRule *> *)allowRules
                                                               blockRules:(NSArray<NTYTRule *> *)blockRules
                                                            existingStates:(NSDictionary<NSString *, NSNumber *> *)existingStates {
    NSMutableSet<NSString *> *usedGroups = [NSMutableSet set];
    for (NTYTRule *rule in allowRules) {
        if (rule.group.length > 0) [usedGroups addObject:rule.group];
    }
    for (NTYTRule *rule in blockRules) {
        if (rule.group.length > 0) [usedGroups addObject:rule.group];
    }

    NSMutableDictionary<NSString *, NSNumber *> *pruned = [NSMutableDictionary dictionary];
    for (NSString *group in usedGroups) {
        NSNumber *stored = existingStates[group];
        if (stored) pruned[group] = stored;
    }
    return [pruned copy];
}

static NSString *NTYTBaseTitle(NTYTField field) {
    switch (field) {
        case NTYTFieldGeneralText: return @"General";
        case NTYTFieldVideoText: return @"Video title";
        case NTYTFieldChannelIdentity: return @"Channel";
        case NTYTFieldVideoID: return @"Video ID";
        default: return @"Other";
    }
}

- (NSString *)subtitleForRule:(NTYTRule *)rule {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:NTYTBaseTitle(rule.baseField)];
    if (!rule.isEnabled) [parts addObject:@"Disabled"];
    if (rule.group.length > 0) {
        BOOL groupEnabled = self.manager.groupStates[rule.group] == nil
            ? YES : self.manager.groupStates[rule.group].boolValue;
        [parts addObject:[NSString stringWithFormat:@"Group: %@%@",
                          rule.group,
                          groupEnabled ? @"" : @" (Off)"]];
    }
    return [parts componentsJoinedByString:@" · "];
}

#pragma mark - Table structure

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.scope == NTYTRuleListScopeCustomRules) {
        return 1 + self.buckets.count;
    }
    return self.buckets.count;
}

- (NTYTRuleBucket *)bucketForTableSection:(NSInteger)section {
    if (self.scope == NTYTRuleListScopeCustomRules) {
        if (section == 0) return nil;
        return self.buckets[section - 1];
    }
    return self.buckets[section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.scope == NTYTRuleListScopeCustomRules && section == 0) {
        return MAX((NSInteger)self.allGroupNames.count, 1);
    }

    NTYTRuleBucket *bucket = [self bucketForTableSection:section];
    NSArray *rules = [self rulesForBucket:bucket];
    return rules.count + 1 + bucket.optionKinds.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.scope == NTYTRuleListScopeCustomRules && section == 0) {
        return @"Groups";
    }
    return [self bucketForTableSection:section].title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (self.scope == NTYTRuleListScopeCustomRules && section == 0) {
        return @"Assign a group name in a Custom Rule. Group switches disable/enable all rules in that group without deleting them.";
    }

    NTYTRuleBucket *bucket = [self bucketForTableSection:section];
    if ([bucket.sourceSection isEqualToString:@"videos.id.block"]) {
        return @"Direct 11-character video IDs only. URL parsing is intentionally not used in v1.";
    }
    return nil;
}

#pragma mark - Cells

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.scope == NTYTRuleListScopeCustomRules && indexPath.section == 0) {
        NSArray<NSString *> *groups = self.allGroupNames;
        UITableViewCell *cell =
            [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:nil];
        if (groups.count == 0) {
            cell.textLabel.text = @"No groups";
            cell.textLabel.textColor = UIColor.secondaryLabelColor;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }

        NSString *group = groups[indexPath.row];
        cell.textLabel.text = group;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *toggle = [UISwitch new];
        toggle.tag = indexPath.row;
        NSNumber *stored = self.manager.groupStates[group];
        toggle.on = stored == nil ? YES : stored.boolValue;
        [toggle addTarget:self
                   action:@selector(groupSwitchChanged:)
         forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        return cell;
    }

    NTYTRuleBucket *bucket = [self bucketForTableSection:indexPath.section];
    NSArray<NTYTRule *> *rules = [self rulesForBucket:bucket];

    if (indexPath.row < rules.count) {
        NTYTRule *rule = rules[indexPath.row];
        UITableViewCell *cell =
            [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                  reuseIdentifier:nil];
        cell.textLabel.text = rule.sourceText.length > 0 ? rule.sourceText : rule.identifier;
        cell.textLabel.numberOfLines = 2;
        cell.detailTextLabel.text = [self subtitleForRule:rule];
        cell.detailTextLabel.numberOfLines = 2;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (!rule.isEnabled) {
            cell.textLabel.textColor = UIColor.secondaryLabelColor;
        }
        return cell;
    }

    if (indexPath.row == rules.count) {
        UITableViewCell *cell =
            [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:nil];
        cell.textLabel.text = @"Add Rule…";
        cell.textLabel.textColor = self.view.tintColor;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }

    NSInteger optionIndex = indexPath.row - rules.count - 1;
    NTYTOptionKind optionKind = [bucket.optionKinds[optionIndex] integerValue];
    return [self optionCellForBucket:bucket optionKind:optionKind section:indexPath.section];
}

- (UITableViewCell *)optionCellForBucket:(NTYTRuleBucket *)bucket
                              optionKind:(NTYTOptionKind)optionKind
                                 section:(NSInteger)section {
    UITableViewCell *cell =
        [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                              reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    NSString *title = nil;
    if (optionKind == NTYTOptionKindCaseSensitive) title = @"Case Sensitive";
    if (optionKind == NTYTOptionKindExactMatch) title = @"Exact Match";
    if (optionKind == NTYTOptionKindWordBoundary) title = @"Word Boundary";
    cell.textLabel.text = title;

    NTYTRuleEvaluationOptions *options = self.manager.defaultOptionsBySection[bucket.sourceSection];
    if (!options) options = [NTYTRuleEvaluationOptions defaultOptions];

    BOOL enabled = NO;
    if (optionKind == NTYTOptionKindCaseSensitive) enabled = options.caseSensitive;
    if (optionKind == NTYTOptionKindExactMatch) enabled = options.exactMatch;
    if (optionKind == NTYTOptionKindWordBoundary) enabled = options.wordBoundary;

    UISwitch *toggle = [UISwitch new];
    // section occupies the high digits, option kind the low digit.
    toggle.tag = (section * 10) + optionKind;
    toggle.on = enabled;
    [toggle addTarget:self
               action:@selector(optionSwitchChanged:)
     forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}

#pragma mark - Selection / editing

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (self.scope == NTYTRuleListScopeCustomRules && indexPath.section == 0) {
        return;
    }

    NTYTRuleBucket *bucket = [self bucketForTableSection:indexPath.section];
    NSArray<NTYTRule *> *rules = [self rulesForBucket:bucket];

    if (indexPath.row < rules.count) {
        [self presentEditorForRule:rules[indexPath.row] bucket:bucket];
    } else if (indexPath.row == rules.count) {
        [self presentEditorForRule:nil bucket:bucket];
    }
}

- (void)presentEditorForRule:(NTYTRule *)rule bucket:(NTYTRuleBucket *)bucket {
    BOOL custom = self.scope == NTYTRuleListScopeCustomRules;

    NTYTRuleEditorAction initialAction = bucket.action;
    if (custom && rule) {
        initialAction = [rule.sourceSection isEqualToString:@"custom.allow"]
            ? NTYTRuleEditorActionAllow : NTYTRuleEditorActionBlock;
    }

    __weak typeof(self) weakSelf = self;
    NTYTRuleEditorController *editor =
        [[NTYTRuleEditorController alloc]
            initWithRule:rule
            action:initialAction
            fixedSourceSection:custom ? nil : bucket.sourceSection
            fixedBaseField:custom ? NTYTFieldUnknown : bucket.baseField
            allowActionSelection:custom
            allowBaseFieldSelection:custom
            allowGroup:custom
            saveBlock:^(NTYTRule *savedRule,
                        NTYTRuleEditorAction action,
                        NSString *replacingIdentifier) {
        [weakSelf applySavedRule:savedRule
                          action:action
             replacingIdentifier:replacingIdentifier];
    }];

    [self.navigationController pushViewController:editor animated:YES];
}

- (void)applySavedRule:(NTYTRule *)rule
                action:(NTYTRuleEditorAction)action
   replacingIdentifier:(NSString *)replacingIdentifier {
    NSMutableArray<NTYTRule *> *allow = [self.manager.allowRules mutableCopy];
    NSMutableArray<NTYTRule *> *block = [self.manager.blockRules mutableCopy];

    if (replacingIdentifier.length > 0) {
        NSPredicate *keep = [NSPredicate predicateWithBlock:^BOOL(NTYTRule *candidate, NSDictionary *bindings) {
            return ![candidate.identifier isEqualToString:replacingIdentifier];
        }];
        allow = [[allow filteredArrayUsingPredicate:keep] mutableCopy];
        block = [[block filteredArrayUsingPredicate:keep] mutableCopy];
    }

    if (action == NTYTRuleEditorActionAllow) {
        [allow addObject:rule];
    } else {
        [block addObject:rule];
    }

    NSDictionary<NSString *, NSNumber *> *groupStates =
        [self prunedGroupStatesForAllowRules:allow
                                  blockRules:block
                               existingStates:self.manager.groupStates];

    [self persistAllowRules:allow
                 blockRules:block
                 groupStates:groupStates
                     options:self.manager.defaultOptionsBySection];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.scope == NTYTRuleListScopeCustomRules && indexPath.section == 0) return NO;
    NTYTRuleBucket *bucket = [self bucketForTableSection:indexPath.section];
    return indexPath.row < [self rulesForBucket:bucket].count;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;

    NTYTRuleBucket *bucket = [self bucketForTableSection:indexPath.section];
    NSArray<NTYTRule *> *rules = [self rulesForBucket:bucket];
    if (indexPath.row >= rules.count) return;

    NSString *identifier = rules[indexPath.row].identifier;
    NSMutableArray<NTYTRule *> *allow = [NSMutableArray array];
    NSMutableArray<NTYTRule *> *block = [NSMutableArray array];

    for (NTYTRule *rule in self.manager.allowRules) {
        if (![rule.identifier isEqualToString:identifier]) [allow addObject:rule];
    }
    for (NTYTRule *rule in self.manager.blockRules) {
        if (![rule.identifier isEqualToString:identifier]) [block addObject:rule];
    }

    NSDictionary<NSString *, NSNumber *> *groupStates =
        [self prunedGroupStatesForAllowRules:allow
                                  blockRules:block
                               existingStates:self.manager.groupStates];

    [self persistAllowRules:allow
                 blockRules:block
                 groupStates:groupStates
                     options:self.manager.defaultOptionsBySection];
}

#pragma mark - Option / group switches

- (void)optionSwitchChanged:(UISwitch *)sender {
    NSInteger section = sender.tag / 10;
    NTYTOptionKind kind = sender.tag % 10;
    NTYTRuleBucket *bucket = [self bucketForTableSection:section];
    if (!bucket) return;

    NTYTRuleEvaluationOptions *old = self.manager.defaultOptionsBySection[bucket.sourceSection];
    if (!old) old = [NTYTRuleEvaluationOptions defaultOptions];

    BOOL caseSensitive = old.caseSensitive;
    BOOL exactMatch = old.exactMatch;
    BOOL wordBoundary = old.wordBoundary;

    if (kind == NTYTOptionKindCaseSensitive) caseSensitive = sender.isOn;
    if (kind == NTYTOptionKindExactMatch) exactMatch = sender.isOn;
    if (kind == NTYTOptionKindWordBoundary) wordBoundary = sender.isOn;

    NTYTRuleEvaluationOptions *updated =
        [NTYTRuleEvaluationOptions optionsWithCaseSensitive:caseSensitive
                                                 exactMatch:exactMatch
                                               wordBoundary:wordBoundary];

    NSMutableDictionary *options = [self.manager.defaultOptionsBySection mutableCopy];
    options[bucket.sourceSection] = updated;

    [self persistAllowRules:self.manager.allowRules
                 blockRules:self.manager.blockRules
                 groupStates:self.manager.groupStates
                     options:options];
}

- (void)groupSwitchChanged:(UISwitch *)sender {
    NSArray<NSString *> *groups = self.allGroupNames;
    if (sender.tag < 0 || sender.tag >= groups.count) return;

    NSString *group = groups[sender.tag];
    NSMutableDictionary<NSString *, NSNumber *> *states =
        [self.manager.groupStates mutableCopy];
    states[group] = @(sender.isOn);

    [self persistAllowRules:self.manager.allowRules
                 blockRules:self.manager.blockRules
                 groupStates:states
                     options:self.manager.defaultOptionsBySection];
}

#pragma mark - Persistence

- (void)persistAllowRules:(NSArray<NTYTRule *> *)allowRules
               blockRules:(NSArray<NTYTRule *> *)blockRules
               groupStates:(NSDictionary<NSString *, NSNumber *> *)groupStates
                   options:(NSDictionary<NSString *, NTYTRuleEvaluationOptions *> *)options {
    NSError *error = nil;
    BOOL ok = [self.manager replaceAllowRules:allowRules
                                   blockRules:blockRules
                                   groupStates:groupStates
                       defaultOptionsBySection:options
                                         error:&error];
    if (!ok) {
        NTYTLog(@"[NTYT][UI] save failed: %@", error);
        [self showSaveError:error.localizedDescription ?: @"Unknown Rule Manager error."];
        return;
    }

    NTYTLog(@"[NTYT][UI] saved from %@ screen allow=%lu block=%lu",
            self.title ?: @"Rules",
            (unsigned long)self.manager.allowRules.count,
            (unsigned long)self.manager.blockRules.count);
    [self.tableView reloadData];
}

- (void)showSaveError:(NSString *)message {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"NoThankYouTube Save Error"
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
