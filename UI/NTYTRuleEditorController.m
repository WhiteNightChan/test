#import "NTYTRuleEditorController.h"

#import "../Rule/NTYTCondition.h"
#import "../Rule/NTYTRuleParser.h"
#import "../Rule/NTYTRuleTypes.h"

@interface NTYTRuleEditorController () <UITextViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong, nullable) NTYTRule *editingRule;
@property (nonatomic) NTYTRuleEditorAction ruleAction;
@property (nonatomic, copy, nullable) NSString *fixedSourceSection;
@property (nonatomic) NTYTField fixedBaseField;
@property (nonatomic) BOOL allowActionSelection;
@property (nonatomic) BOOL allowBaseFieldSelection;
@property (nonatomic) BOOL allowGroup;
@property (nonatomic, copy) NTYTRuleEditorSaveBlock saveBlock;

@property (nonatomic) NTYTField selectedBaseField;
@property (nonatomic) BOOL selectedEnabled;
@property (nonatomic) NTYTMatcher selectedMatcher;
@property (nonatomic) BOOL selectedNegated;
@property (nonatomic, copy) NSString *sourceText;
@property (nonatomic, copy) NSString *initialSourceText;
@property (nonatomic, copy) NSString *groupText;

@property (nonatomic) BOOL matcherTouched;
@property (nonatomic) BOOL negatedTouched;
@property (nonatomic) BOOL caseOverrideTouched;
@property (nonatomic) BOOL exactOverrideTouched;
@property (nonatomic) BOOL boundaryOverrideTouched;

@property (nonatomic) NTYTOptionOverride caseOverride;
@property (nonatomic) NTYTOptionOverride exactOverride;
@property (nonatomic) NTYTOptionOverride boundaryOverride;

@property (nonatomic, strong) UITextView *sourceTextView;
@property (nonatomic, strong) UITextField *groupTextField;

@end

@implementation NTYTRuleEditorController

- (instancetype)initWithRule:(NTYTRule *)rule
                      action:(NTYTRuleEditorAction)action
          fixedSourceSection:(NSString *)fixedSourceSection
              fixedBaseField:(NTYTField)fixedBaseField
        allowActionSelection:(BOOL)allowActionSelection
     allowBaseFieldSelection:(BOOL)allowBaseFieldSelection
                  allowGroup:(BOOL)allowGroup
                   saveBlock:(NTYTRuleEditorSaveBlock)saveBlock {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (!self) {
        return nil;
    }

    _editingRule = rule;
    _ruleAction = action;
    _fixedSourceSection = [fixedSourceSection copy];
    _fixedBaseField = fixedBaseField;
    _allowActionSelection = allowActionSelection;
    _allowBaseFieldSelection = allowBaseFieldSelection;
    _allowGroup = allowGroup;
    _saveBlock = [saveBlock copy];

    _selectedBaseField = rule ? rule.baseField :
        (fixedBaseField != NTYTFieldUnknown ? fixedBaseField : NTYTFieldGeneralText);
    _selectedEnabled = rule ? rule.isEnabled : YES;
    _sourceText = [rule.sourceText copy] ?: @"";
    _initialSourceText = [_sourceText copy];
    _groupText = [rule.group copy] ?: @"";

    NTYTCondition *first = rule.predicates.firstObject;
    _selectedMatcher = first ? first.matcher : NTYTMatcherContains;
    _selectedNegated = first ? first.isNegated : NO;

    _caseOverride = first ? first.caseSensitiveOverride : NTYTOptionOverrideInherit;
    _exactOverride = first ? first.exactMatchOverride : NTYTOptionOverrideInherit;
    _boundaryOverride = first ? first.wordBoundaryOverride : NTYTOptionOverrideInherit;

    // If an existing advanced rule has different overrides per predicate, the
    // segmented control shows Inherit. Untouched controls still preserve each
    // existing predicate exactly when the source text itself is unchanged.
    BOOL mixedCase = NO;
    BOOL mixedExact = NO;
    BOOL mixedBoundary = NO;
    for (NTYTCondition *condition in rule.predicates) {
        if (condition.caseSensitiveOverride != _caseOverride) mixedCase = YES;
        if (condition.exactMatchOverride != _exactOverride) mixedExact = YES;
        if (condition.wordBoundaryOverride != _boundaryOverride) mixedBoundary = YES;
    }
    if (mixedCase) _caseOverride = NTYTOptionOverrideInherit;
    if (mixedExact) _exactOverride = NTYTOptionOverrideInherit;
    if (mixedBoundary) _boundaryOverride = NTYTOptionOverrideInherit;

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = self.editingRule ? @"Edit Rule" : @"Add Rule";
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                     target:self
                                                     action:@selector(saveTapped)];

    [self.tableView registerClass:UITableViewCell.class
           forCellReuseIdentifier:@"Cell"];
}

#pragma mark - Sections

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Enabled / action / base / operator / negate / value-source / options / group / help
    return 9;
}

- (BOOL)allowsOptionOverrides {
    // Videos / Video ID is intentionally fixed to exact + case-sensitive v1 semantics.
    return ![self.fixedSourceSection isEqualToString:@"videos.id.block"];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1;
        case 1: return self.allowActionSelection ? 1 : 0;
        case 2: return self.allowBaseFieldSelection ? 1 : 0;
        case 3: return self.allowBaseFieldSelection ? 1 : 0;
        case 4: return self.allowBaseFieldSelection ? 1 : 0;
        case 5: return 1;
        case 6: return [self allowsOptionOverrides] ? 3 : 0;
        case 7: return self.allowGroup ? 1 : 0;
        case 8: return 1;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"State";
        case 1: return self.allowActionSelection ? @"Action" : nil;
        case 2: return self.allowBaseFieldSelection ? @"Base Target / Field" : nil;
        case 3: return self.allowBaseFieldSelection ? @"Operator" : nil;
        case 4: return self.allowBaseFieldSelection ? @"Negate" : nil;
        case 5: return @"Value / Rule Source";
        case 6: return [self allowsOptionOverrides] ? @"Option Overrides" : nil;
        case 7: return self.allowGroup ? @"Group" : nil;
        case 8: return @"Advanced Syntax";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 3 && self.allowBaseFieldSelection) {
        return @"Operator applies to the first/base predicate. Advanced modifiers and $& may add additional predicates.";
    }
    if (section == 4 && self.allowBaseFieldSelection) {
        return @"Negate applies to the first/base predicate only.";
    }
    if (section == 5) {
        return @"For a simple rule this is the value. Advanced syntax is also accepted. One editor entry must compile to exactly one Rule.";
    }
    if (section == 6 && [self allowsOptionOverrides]) {
        return @"Inherit preserves section defaults and parser/modifier-produced overrides. On/Off explicitly overrides them.";
    }
    return nil;
}

#pragma mark - Cells

static NSString *NTYTBaseFieldTitle(NTYTField field) {
    switch (field) {
        case NTYTFieldGeneralText: return @"General";
        case NTYTFieldVideoText: return @"Video title";
        case NTYTFieldChannelIdentity: return @"Channel";
        case NTYTFieldVideoID: return @"Video ID";
        default: return @"Unknown";
    }
}

static NSString *NTYTMatcherTitle(NTYTMatcher matcher) {
    switch (matcher) {
        case NTYTMatcherExact: return @"Exact";
        case NTYTMatcherRegex: return @"Regex";
        case NTYTMatcherContains:
        default: return @"Contains";
    }
}

static NSInteger NTYTSegmentIndexFromOverride(NTYTOptionOverride value) {
    switch (value) {
        case NTYTOptionOverrideForceOn: return 1;
        case NTYTOptionOverrideForceOff: return 2;
        case NTYTOptionOverrideInherit:
        default: return 0;
    }
}

static NTYTOptionOverride NTYTOverrideFromSegmentIndex(NSInteger index) {
    if (index == 1) return NTYTOptionOverrideForceOn;
    if (index == 2) return NTYTOptionOverrideForceOff;
    return NTYTOptionOverrideInherit;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                              reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (indexPath.section == 0) {
        cell.textLabel.text = @"Enabled";
        UISwitch *toggle = [UISwitch new];
        toggle.on = self.selectedEnabled;
        [toggle addTarget:self
                   action:@selector(enabledChanged:)
         forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        return cell;
    }

    if (indexPath.section == 1) {
        cell.textLabel.text = @"Action";
        cell.detailTextLabel.text =
            self.ruleAction == NTYTRuleEditorActionAllow ? @"Allow" : @"Block";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }

    if (indexPath.section == 2) {
        cell.textLabel.text = @"Base target";
        cell.detailTextLabel.text = NTYTBaseFieldTitle(self.selectedBaseField);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }

    if (indexPath.section == 3) {
        cell.textLabel.text = @"Operator";
        cell.detailTextLabel.text = NTYTMatcherTitle(self.selectedMatcher);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }

    if (indexPath.section == 4) {
        cell.textLabel.text = @"Negate base predicate";
        UISwitch *toggle = [UISwitch new];
        toggle.on = self.selectedNegated;
        [toggle addTarget:self
                   action:@selector(negatedChanged:)
         forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        return cell;
    }

    if (indexPath.section == 5) {
        self.sourceTextView = [[UITextView alloc] initWithFrame:CGRectZero];
        self.sourceTextView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        self.sourceTextView.text = self.sourceText ?: @"";
        self.sourceTextView.delegate = self;
        self.sourceTextView.autocorrectionType = UITextAutocorrectionTypeNo;
        self.sourceTextView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.sourceTextView.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:self.sourceTextView];
        [NSLayoutConstraint activateConstraints:@[
            [self.sourceTextView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:12.0],
            [self.sourceTextView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-12.0],
            [self.sourceTextView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:6.0],
            [self.sourceTextView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-6.0],
            [self.sourceTextView.heightAnchor constraintGreaterThanOrEqualToConstant:110.0],
        ]];
        return cell;
    }

    if (indexPath.section == 6) {
        NSArray<NSString *> *titles = @[@"Case Sensitive", @"Exact Match", @"Word Boundary"];
        cell.textLabel.text = titles[indexPath.row];

        UISegmentedControl *segmented =
            [[UISegmentedControl alloc] initWithItems:@[@"Inherit", @"On", @"Off"]];
        segmented.tag = indexPath.row;

        NTYTOptionOverride value = NTYTOptionOverrideInherit;
        if (indexPath.row == 0) value = self.caseOverride;
        if (indexPath.row == 1) value = self.exactOverride;
        if (indexPath.row == 2) value = self.boundaryOverride;
        segmented.selectedSegmentIndex = NTYTSegmentIndexFromOverride(value);

        [segmented addTarget:self
                      action:@selector(optionOverrideChanged:)
            forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = segmented;
        return cell;
    }

    if (indexPath.section == 7) {
        self.groupTextField = [[UITextField alloc] initWithFrame:CGRectZero];
        self.groupTextField.placeholder = @"Optional group name";
        self.groupTextField.text = self.groupText ?: @"";
        self.groupTextField.delegate = self;
        self.groupTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
        self.groupTextField.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:self.groupTextField];
        [NSLayoutConstraint activateConstraints:@[
            [self.groupTextField.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16.0],
            [self.groupTextField.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16.0],
            [self.groupTextField.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:8.0],
            [self.groupTextField.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8.0],
            [self.groupTextField.heightAnchor constraintGreaterThanOrEqualToConstant:32.0],
        ]];
        return cell;
    }

    cell.textLabel.numberOfLines = 0;
    cell.textLabel.text = @"Examples:\n自作PC\n!ニュース\n/自作pc/i\n自作PC $& ニュース\n${ch: /^Aile ニュースCh\\.$/} 自作PC";
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 5) return 132.0;
    if (indexPath.section == 8) return 150.0;
    return UITableViewAutomaticDimension;
}

#pragma mark - Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 1 && self.allowActionSelection) {
        [self presentActionPicker];
    } else if (indexPath.section == 2 && self.allowBaseFieldSelection) {
        [self presentBaseTargetPicker];
    } else if (indexPath.section == 3 && self.allowBaseFieldSelection) {
        [self presentMatcherPicker];
    }
}

- (void)presentActionPicker {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Action"
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Block"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        weakSelf.ruleAction = NTYTRuleEditorActionBlock;
        [weakSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                          withRowAnimation:UITableViewRowAnimationNone];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Allow / Whitelist"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        weakSelf.ruleAction = NTYTRuleEditorActionAllow;
        [weakSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                          withRowAnimation:UITableViewRowAnimationNone];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentBaseTargetPicker {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Base Target"
                                            message:@"Required for Custom Rules"
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray<NSDictionary *> *items = @[
        @{@"title": @"General", @"field": @(NTYTFieldGeneralText)},
        @{@"title": @"Video title", @"field": @(NTYTFieldVideoText)},
        @{@"title": @"Channel", @"field": @(NTYTFieldChannelIdentity)},
        @{@"title": @"Video ID", @"field": @(NTYTFieldVideoID)},
    ];

    __weak typeof(self) weakSelf = self;
    for (NSDictionary *item in items) {
        [alert addAction:[UIAlertAction actionWithTitle:item[@"title"]
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            weakSelf.selectedBaseField = [item[@"field"] integerValue];
            [weakSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:2]
                              withRowAnimation:UITableViewRowAnimationNone];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentMatcherPicker {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Operator"
                                            message:@"Applies to the first/base predicate"
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    __weak typeof(self) weakSelf = self;
    NSArray<NSDictionary *> *items = @[
        @{@"title": @"Contains", @"matcher": @(NTYTMatcherContains)},
        @{@"title": @"Exact", @"matcher": @(NTYTMatcherExact)},
        @{@"title": @"Regex", @"matcher": @(NTYTMatcherRegex)},
    ];

    for (NSDictionary *item in items) {
        [alert addAction:[UIAlertAction actionWithTitle:item[@"title"]
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            weakSelf.selectedMatcher = [item[@"matcher"] integerValue];
            weakSelf.matcherTouched = YES;
            [weakSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:3]
                              withRowAnimation:UITableViewRowAnimationNone];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Controls

- (void)enabledChanged:(UISwitch *)sender {
    self.selectedEnabled = sender.isOn;
}

- (void)negatedChanged:(UISwitch *)sender {
    self.selectedNegated = sender.isOn;
    self.negatedTouched = YES;
}

- (void)optionOverrideChanged:(UISegmentedControl *)sender {
    NTYTOptionOverride value = NTYTOverrideFromSegmentIndex(sender.selectedSegmentIndex);
    if (sender.tag == 0) {
        self.caseOverride = value;
        self.caseOverrideTouched = YES;
    }
    if (sender.tag == 1) {
        self.exactOverride = value;
        self.exactOverrideTouched = YES;
    }
    if (sender.tag == 2) {
        self.boundaryOverride = value;
        self.boundaryOverrideTouched = YES;
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    self.sourceText = textView.text ?: @"";
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField == self.groupTextField) {
        self.groupText = textField.text ?: @"";
    }
}

#pragma mark - Save

static NSString *NTYTTrimmed(NSString *string) {
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static BOOL NTYTIsDirectVideoIDSource(NSString *source) {
    if (source.length != 11) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"];
    return [source rangeOfCharacterFromSet:[allowed invertedSet]].location == NSNotFound;
}

- (void)saveTapped {
    [self.view endEditing:YES];
    self.sourceText = self.sourceTextView.text ?: self.sourceText ?: @"";
    self.groupText = self.groupTextField.text ?: self.groupText ?: @"";

    NSString *source = NTYTTrimmed(self.sourceText);
    if (source.length == 0) {
        [self showErrorMessage:@"Rule Source must not be empty."];
        return;
    }

    NTYTField baseField = self.allowBaseFieldSelection
        ? self.selectedBaseField
        : self.fixedBaseField;
    if (baseField == NTYTFieldUnknown) {
        [self showErrorMessage:@"Base Target is required."];
        return;
    }

    NSString *sourceSection = self.fixedSourceSection;
    if (self.allowActionSelection) {
        sourceSection = self.ruleAction == NTYTRuleEditorActionAllow
            ? @"custom.allow"
            : @"custom.block";
    }
    if (sourceSection.length == 0) {
        [self showErrorMessage:@"Internal error: source section is missing."];
        return;
    }

    if ([sourceSection isEqualToString:@"videos.id.block"] &&
        !NTYTIsDirectVideoIDSource(source)) {
        [self showErrorMessage:@"Video ID rules in the Videos section must be a direct 11-character video ID (no URL/parser syntax). Use Custom Rules for regex or compound ID logic."];
        return;
    }

    NSError *parseError = nil;
    NSString *identifierPrefix =
        [NSString stringWithFormat:@"ui.%@", [[NSUUID UUID] UUIDString]];
    NTYTRuleParserResult *result =
        [NTYTRuleParser parseSource:source
                      sourceSection:sourceSection
                          baseField:baseField
                   identifierPrefix:identifierPrefix
                              error:&parseError];

    if (!result) {
        [self showErrorMessage:parseError.localizedDescription ?: @"Rule parser failed."];
        return;
    }

    if (result.rules.count != 1) {
        [self showErrorMessage:@"One editor entry must compile to exactly one Rule. Add comma/newline-separated rules as separate entries."];
        return;
    }

    NTYTRule *parsed = result.rules.firstObject;
    NSMutableArray<NTYTCondition *> *predicates =
        [NSMutableArray arrayWithCapacity:parsed.predicates.count];

    NSString *initialTrimmed = NTYTTrimmed(self.initialSourceText ?: @"");
    BOOL sourceUnchanged = self.editingRule != nil && [source isEqualToString:initialTrimmed];

    [parsed.predicates enumerateObjectsUsingBlock:^(NTYTCondition *condition,
                                                     NSUInteger index,
                                                     BOOL *stop) {
        NTYTCondition *existing = nil;
        if (sourceUnchanged && index < self.editingRule.predicates.count) {
            existing = self.editingRule.predicates[index];
        }

        NTYTOptionOverride caseValue = condition.caseSensitiveOverride;
        NTYTOptionOverride exactValue = condition.exactMatchOverride;
        NTYTOptionOverride boundaryValue = condition.wordBoundaryOverride;

        if (!self.caseOverrideTouched && existing) {
            caseValue = existing.caseSensitiveOverride;
        } else if (self.caseOverrideTouched && self.caseOverride != NTYTOptionOverrideInherit) {
            caseValue = self.caseOverride;
        }

        if (!self.exactOverrideTouched && existing) {
            exactValue = existing.exactMatchOverride;
        } else if (self.exactOverrideTouched && self.exactOverride != NTYTOptionOverrideInherit) {
            exactValue = self.exactOverride;
        }

        if (!self.boundaryOverrideTouched && existing) {
            boundaryValue = existing.wordBoundaryOverride;
        } else if (self.boundaryOverrideTouched && self.boundaryOverride != NTYTOptionOverrideInherit) {
            boundaryValue = self.boundaryOverride;
        }

        NTYTMatcher matcher = condition.matcher;
        BOOL negated = condition.isNegated;
        if (index == 0 && self.allowBaseFieldSelection) {
            if (!self.matcherTouched && existing) {
                matcher = existing.matcher;
            } else if (self.matcherTouched) {
                matcher = self.selectedMatcher;
            }

            if (!self.negatedTouched && existing) {
                negated = existing.isNegated;
            } else if (self.negatedTouched) {
                negated = self.selectedNegated;
            }
        }

        NTYTCondition *rewritten =
            [[NTYTCondition alloc]
                initWithField:condition.field
                matcher:matcher
                value:condition.value
                regexFlags:condition.regexFlags
                negated:negated
                caseSensitiveOverride:caseValue
                exactMatchOverride:exactValue
                wordBoundaryOverride:boundaryValue];
        [predicates addObject:rewritten];
    }];

    NSString *group = self.allowGroup ? NTYTTrimmed(self.groupText) : @"";
    NSString *identifier = self.editingRule.identifier ?: parsed.identifier;

    NTYTRule *finalRule =
        [[NTYTRule alloc]
            initWithIdentifier:identifier
            enabled:self.selectedEnabled
            group:group.length > 0 ? group : nil
            sourceSection:sourceSection
            baseField:baseField
            sourceText:source
            predicates:predicates];

    if (result.unsupportedModifiers.count > 0) {
        NSString *message = [NSString stringWithFormat:
            @"This rule contains unsupported modifier(s): %@. The rule remains valid but evaluates UNKNOWN while those providers/semantics are unavailable.",
            [result.unsupportedModifiers componentsJoinedByString:@", "]];
        [self confirmSaveRule:finalRule message:message];
        return;
    }

    [self finishSaveRule:finalRule];
}

- (void)confirmSaveRule:(NTYTRule *)rule message:(NSString *)message {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Unsupported condition"
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Save Anyway"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf finishSaveRule:rule];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)finishSaveRule:(NTYTRule *)rule {
    NSString *replacingIdentifier = self.editingRule.identifier;
    if (self.saveBlock) {
        self.saveBlock(rule, self.ruleAction, replacingIdentifier);
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)showErrorMessage:(NSString *)message {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Cannot Save Rule"
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
