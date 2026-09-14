#import <Foundation/Foundation.h>

@class NTYTVideoMetadata;

NS_ASSUME_NONNULL_BEGIN

// Phase 4 bridge.
//
// Receives metadata that was already extracted from YTIElementRenderer,
// evaluates it with the existing RuleEvaluator, and currently compiles the
// temporary "自作PC" source through NTYTRuleParser once at startup.
//
//
// This function is intentionally limited to the current standalone normal
// video path:
//   is_video = YES
//   is_short = NO
//
// Missing future-provider fields remain UNKNOWN.
FOUNDATION_EXPORT BOOL NTYTShouldBlockStandaloneVideoMetadata(
    NTYTVideoMetadata *metadata
);

NS_ASSUME_NONNULL_END
