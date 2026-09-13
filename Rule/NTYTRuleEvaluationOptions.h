#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NTYTRuleEvaluationOptions : NSObject <NSCopying>

@property (nonatomic, readonly) BOOL caseSensitive;
@property (nonatomic, readonly) BOOL exactMatch;
@property (nonatomic, readonly) BOOL wordBoundary;

+ (instancetype)optionsWithCaseSensitive:(BOOL)caseSensitive
                              exactMatch:(BOOL)exactMatch
                            wordBoundary:(BOOL)wordBoundary;

+ (instancetype)defaultOptions;

@end

NS_ASSUME_NONNULL_END
