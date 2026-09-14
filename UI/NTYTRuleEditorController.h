#import <UIKit/UIKit.h>

#import "../Rule/NTYTRule.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NTYTRuleEditorAction) {
    NTYTRuleEditorActionBlock = 0,
    NTYTRuleEditorActionAllow,
};

typedef void (^NTYTRuleEditorSaveBlock)(
    NTYTRule *rule,
    NTYTRuleEditorAction action,
    NSString * _Nullable replacingIdentifier
);

@interface NTYTRuleEditorController : UITableViewController

- (instancetype)initWithRule:(nullable NTYTRule *)rule
                      action:(NTYTRuleEditorAction)action
          fixedSourceSection:(nullable NSString *)fixedSourceSection
              fixedBaseField:(NTYTField)fixedBaseField
        allowActionSelection:(BOOL)allowActionSelection
     allowBaseFieldSelection:(BOOL)allowBaseFieldSelection
                  allowGroup:(BOOL)allowGroup
                   saveBlock:(NTYTRuleEditorSaveBlock)saveBlock
    NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithStyle:(UITableViewStyle)style NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
