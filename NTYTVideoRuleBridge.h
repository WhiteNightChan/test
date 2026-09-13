#import <Foundation/Foundation.h>

@class NTYTVideoMetadata;

NS_ASSUME_NONNULL_BEGIN

// Phase 3 bridge.
//
// Receives metadata that was already extracted from YTIElementRenderer and
// evaluates it with the Phase 2 rule engine.
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
