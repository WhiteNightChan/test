#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NTYTRuleListScope) {
    NTYTRuleListScopeGeneral = 0,
    NTYTRuleListScopeVideos,
    NTYTRuleListScopeChannels,
    NTYTRuleListScopeCustomRules,
};

@interface NTYTRuleListController : UITableViewController

- (instancetype)initWithScope:(NTYTRuleListScope)scope NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithStyle:(UITableViewStyle)style NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
