#import "NTYTRuleEvaluationOptions.h"

@interface NTYTRuleEvaluationOptions ()

- (instancetype)initWithCaseSensitive:(BOOL)caseSensitive
                           exactMatch:(BOOL)exactMatch
                         wordBoundary:(BOOL)wordBoundary;

@end

@implementation NTYTRuleEvaluationOptions

- (instancetype)initWithCaseSensitive:(BOOL)caseSensitive
                           exactMatch:(BOOL)exactMatch
                         wordBoundary:(BOOL)wordBoundary {
    self = [super init];

    if (self) {
        _caseSensitive = caseSensitive;
        _exactMatch = exactMatch;
        _wordBoundary = wordBoundary;
    }

    return self;
}

+ (instancetype)optionsWithCaseSensitive:(BOOL)caseSensitive
                              exactMatch:(BOOL)exactMatch
                            wordBoundary:(BOOL)wordBoundary {
    return [[self alloc] initWithCaseSensitive:caseSensitive
                                    exactMatch:exactMatch
                                  wordBoundary:wordBoundary];
}

+ (instancetype)defaultOptions {
    return [self optionsWithCaseSensitive:NO
                               exactMatch:NO
                             wordBoundary:NO];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

@end
