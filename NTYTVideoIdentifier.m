#import "NTYTVideoIdentifier.h"

#import <YouTubeHeader/YTIElementRenderer.h>

@interface YTIElementRenderer (NTYTElementData)
- (nullable NSData *)elementData;
@end

static const NSUInteger kNTYTMaxDepth = 32;
static const NSUInteger kNTYTMaxMatches = 32;

typedef struct {
    uint32_t number;
    uint8_t wireType;

    NSUInteger payloadStart;
    NSUInteger payloadLength;

    uint64_t varintValue;
    BOOL hasVarintValue;
} NTYTProtoField;

typedef BOOL (^NTYTFieldVisitor)(NTYTProtoField field);


@interface NTYTVideoMetadata ()

@property (nonatomic, copy, readwrite) NSString *videoID;
@property (nonatomic, copy, readwrite, nullable) NSString *title;
@property (nonatomic, copy, readwrite, nullable) NSString *channelID;
@property (nonatomic, copy, readwrite, nullable) NSString *channelName;
@property (nonatomic, copy, readwrite, nullable) NSString *handle;
@property (nonatomic, copy, readwrite, nullable) NSString *viewCountText;

@end


@implementation NTYTVideoMetadata
@end


#pragma mark - Low-level protobuf reader

static BOOL NTYTReadVarint(
    const uint8_t *bytes,
    NSUInteger end,
    NSUInteger *position,
    uint64_t *value
) {
    if (!bytes || !position || !value) {
        return NO;
    }

    NSUInteger pos = *position;
    uint64_t result = 0;

    for (NSUInteger i = 0; i < 10; i++) {
        if (pos >= end) {
            return NO;
        }

        uint8_t b = bytes[pos++];

        if (i == 9 && (b & 0xFE) != 0) {
            return NO;
        }

        result |= ((uint64_t)(b & 0x7F)) << (7 * i);

        if ((b & 0x80) == 0) {
            *position = pos;
            *value = result;
            return YES;
        }
    }

    return NO;
}


static BOOL NTYTVisitMessageFields(
    const uint8_t *bytes,
    NSUInteger start,
    NSUInteger end,
    NTYTFieldVisitor visitor
) {
    if (!bytes || start > end || !visitor) {
        return NO;
    }

    NSUInteger pos = start;

    while (pos < end) {
        uint64_t tag = 0;

        if (!NTYTReadVarint(bytes, end, &pos, &tag)) {
            return NO;
        }

        uint32_t number = (uint32_t)(tag >> 3);
        uint8_t wireType = (uint8_t)(tag & 7);

        if (number == 0) {
            return NO;
        }

        NTYTProtoField field = {
            .number = number,
            .wireType = wireType,
            .payloadStart = 0,
            .payloadLength = 0,
            .varintValue = 0,
            .hasVarintValue = NO
        };

        switch (wireType) {
            case 0: {
                uint64_t value = 0;

                if (!NTYTReadVarint(bytes, end, &pos, &value)) {
                    return NO;
                }

                field.varintValue = value;
                field.hasVarintValue = YES;
                break;
            }

            case 1:
                if (end - pos < 8) {
                    return NO;
                }

                field.payloadStart = pos;
                field.payloadLength = 8;
                pos += 8;
                break;

            case 2: {
                uint64_t length64 = 0;

                if (!NTYTReadVarint(bytes, end, &pos, &length64)) {
                    return NO;
                }

                if (length64 > NSUIntegerMax) {
                    return NO;
                }

                NSUInteger length = (NSUInteger)length64;

                if (length > end - pos) {
                    return NO;
                }

                field.payloadStart = pos;
                field.payloadLength = length;
                pos += length;
                break;
            }

            case 5:
                if (end - pos < 4) {
                    return NO;
                }

                field.payloadStart = pos;
                field.payloadLength = 4;
                pos += 4;
                break;

            default:
                return NO;
        }

        if (!visitor(field)) {
            return YES;
        }
    }

    return pos == end;
}


static BOOL NTYTMessageIsValid(
    const uint8_t *bytes,
    NSUInteger start,
    NSUInteger end
) {
    return NTYTVisitMessageFields(
        bytes,
        start,
        end,
        ^BOOL(NTYTProtoField field) {
            (void)field;
            return YES;
        }
    );
}


#pragma mark - String helpers

static NSString *NTYTUTF8String(
    const uint8_t *bytes,
    NSUInteger start,
    NSUInteger length
) {
    if (!bytes || length == 0) {
        return nil;
    }

    return [[NSString alloc]
        initWithBytes:bytes + start
        length:length
        encoding:NSUTF8StringEncoding];
}


static BOOL NTYTIsVideoID(NSString *value) {
    if (value.length != 11) {
        return NO;
    }

    for (NSUInteger i = 0; i < value.length; i++) {
        unichar c = [value characterAtIndex:i];

        BOOL ok =
            (c >= 'A' && c <= 'Z') ||
            (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') ||
            c == '_' ||
            c == '-';

        if (!ok) {
            return NO;
        }
    }

    return YES;
}


static BOOL NTYTIsChannelID(NSString *value) {
    if (value.length != 24 || ![value hasPrefix:@"UC"]) {
        return NO;
    }

    for (NSUInteger i = 2; i < value.length; i++) {
        unichar c = [value characterAtIndex:i];

        BOOL ok =
            (c >= 'A' && c <= 'Z') ||
            (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') ||
            c == '_' ||
            c == '-';

        if (!ok) {
            return NO;
        }
    }

    return YES;
}


static NSArray<NSString *> *NTYTDirectStringsForField(
    const uint8_t *bytes,
    NSUInteger start,
    NSUInteger end,
    uint32_t wantedField
) {
    NSMutableOrderedSet<NSString *> *values =
        [NSMutableOrderedSet orderedSet];

    BOOL ok = NTYTVisitMessageFields(
        bytes,
        start,
        end,
        ^BOOL(NTYTProtoField field) {
            if (
                field.number == wantedField &&
                field.wireType == 2
            ) {
                NSString *value = NTYTUTF8String(
                    bytes,
                    field.payloadStart,
                    field.payloadLength
                );

                if (value) {
                    [values addObject:value];
                }
            }

            return YES;
        }
    );

    if (!ok) {
        return @[];
    }

    return values.array;
}


#pragma mark - Exact field paths

static void NTYTCollectExactPathRanges(
    const uint8_t *bytes,
    NSUInteger start,
    NSUInteger end,
    const uint32_t *path,
    NSUInteger pathLength,
    NSUInteger pathIndex,
    NSUInteger depth,
    NSMutableArray<NSValue *> *results
) {
    if (
        !bytes ||
        !path ||
        pathLength == 0 ||
        pathIndex >= pathLength ||
        depth > kNTYTMaxDepth ||
        results.count >= kNTYTMaxMatches
    ) {
        return;
    }

    uint32_t wantedField = path[pathIndex];

    NTYTVisitMessageFields(
        bytes,
        start,
        end,
        ^BOOL(NTYTProtoField field) {
            if (
                field.number != wantedField ||
                field.wireType != 2
            ) {
                return YES;
            }

            NSRange range = NSMakeRange(
                field.payloadStart,
                field.payloadLength
            );

            if (pathIndex + 1 == pathLength) {
                [results addObject:[NSValue valueWithRange:range]];

                return results.count < kNTYTMaxMatches;
            }

            if (
                field.payloadLength != 0 &&
                NTYTMessageIsValid(
                    bytes,
                    field.payloadStart,
                    NSMaxRange(range)
                )
            ) {
                NTYTCollectExactPathRanges(
                    bytes,
                    field.payloadStart,
                    NSMaxRange(range),
                    path,
                    pathLength,
                    pathIndex + 1,
                    depth + 1,
                    results
                );
            }

            return results.count < kNTYTMaxMatches;
        }
    );
}


static NSArray<NSValue *> *NTYTExactPathRanges(
    const uint8_t *bytes,
    NSUInteger length,
    const uint32_t *path,
    NSUInteger pathLength
) {
    NSMutableArray<NSValue *> *results =
        [NSMutableArray array];

    NTYTCollectExactPathRanges(
        bytes,
        0,
        length,
        path,
        pathLength,
        0,
        0,
        results
    );

    return results;
}


#pragma mark - video_id

static NSString *NTYTDirectVideoID(
    const uint8_t *bytes,
    NSUInteger start,
    NSUInteger end
) {
    NSMutableOrderedSet<NSString *> *ids =
        [NSMutableOrderedSet orderedSet];

    NSArray<NSString *> *strings =
        NTYTDirectStringsForField(
            bytes,
            start,
            end,
            1
        );

    for (NSString *value in strings) {
        if (NTYTIsVideoID(value)) {
            [ids addObject:value];
        }
    }

    return ids.count == 1
        ? ids.firstObject
        : nil;
}


static void NTYTFindVideoIDsRecursive(
    const uint8_t *bytes,
    NSUInteger start,
    NSUInteger end,
    NSUInteger depth,
    NSMutableOrderedSet<NSString *> *ids
) {
    if (
        depth > kNTYTMaxDepth ||
        ids.count >= kNTYTMaxMatches
    ) {
        return;
    }

    NTYTVisitMessageFields(
        bytes,
        start,
        end,
        ^BOOL(NTYTProtoField field) {
            if (
                field.number == 73080600 &&
                field.wireType == 2
            ) {
                NSString *videoID =
                    NTYTDirectVideoID(
                        bytes,
                        field.payloadStart,
                        field.payloadStart + field.payloadLength
                    );

                if (videoID) {
                    [ids addObject:videoID];
                }
            }

            if (
                field.wireType == 2 &&
                field.payloadLength != 0
            ) {
                NSUInteger childEnd =
                    field.payloadStart + field.payloadLength;

                if (
                    NTYTMessageIsValid(
                        bytes,
                        field.payloadStart,
                        childEnd
                    )
                ) {
                    NTYTFindVideoIDsRecursive(
                        bytes,
                        field.payloadStart,
                        childEnd,
                        depth + 1,
                        ids
                    );
                }
            }

            return ids.count < kNTYTMaxMatches;
        }
    );
}


static NSString *NTYTPrimaryVideoID(
    const uint8_t *bytes,
    NSUInteger length
) {
    NSMutableOrderedSet<NSString *> *ids =
        [NSMutableOrderedSet orderedSet];

    NTYTFindVideoIDsRecursive(
        bytes,
        0,
        length,
        0,
        ids
    );

    return ids.count == 1
        ? ids.firstObject
        : nil;
}


#pragma mark - rich metadata

static const uint32_t kNTYTRichMetadataPath[] = {
    1,
    168777401,
    5,
    232954548,
    18,
    4,
    169495254,
    462702848,
    1,
    200453700,
    1,
    48687757
};


static BOOL NTYTExtractRichMetadata(
    const uint8_t *bytes,
    NSUInteger length,
    NSString *expectedVideoID,
    NSString **titleOut,
    NSString **channelNameOut
) {
    NSArray<NSValue *> *ranges =
        NTYTExactPathRanges(
            bytes,
            length,
            kNTYTRichMetadataPath,
            sizeof(kNTYTRichMetadataPath) /
                sizeof(kNTYTRichMetadataPath[0])
        );

    NSMutableArray<NSValue *> *matchingRanges =
        [NSMutableArray array];

    for (NSValue *value in ranges) {
        NSRange range = value.rangeValue;

        NSArray<NSString *> *ids =
            NTYTDirectStringsForField(
                bytes,
                range.location,
                NSMaxRange(range),
                1
            );

        NSMutableArray<NSString *> *validIDs =
            [NSMutableArray array];

        for (NSString *candidate in ids) {
            if (NTYTIsVideoID(candidate)) {
                [validIDs addObject:candidate];
            }
        }

        if (
            validIDs.count == 1 &&
            [validIDs.firstObject isEqualToString:expectedVideoID]
        ) {
            [matchingRanges addObject:value];
        }
    }

    if (matchingRanges.count != 1) {
        return NO;
    }

    NSRange range =
        matchingRanges.firstObject.rangeValue;

    NSArray<NSString *> *titles =
        NTYTDirectStringsForField(
            bytes,
            range.location,
            NSMaxRange(range),
            36
        );

    NSArray<NSString *> *channelNames =
        NTYTDirectStringsForField(
            bytes,
            range.location,
            NSMaxRange(range),
            37
        );

    if (titleOut) {
        *titleOut =
            titles.count == 1
                ? titles.firstObject
                : nil;
    }

    if (channelNameOut) {
        *channelNameOut =
            channelNames.count == 1
                ? channelNames.firstObject
                : nil;
    }

    return YES;
}


#pragma mark - channel_id / handle

static const uint32_t kNTYTChannelMetadataPath[] = {
    1,
    168777401,
    5,
    232954548,
    18,
    1,
    3,
    5,
    169495254,
    48687626
};


static void NTYTExtractChannelMetadata(
    const uint8_t *bytes,
    NSUInteger length,
    NSString **channelIDOut,
    NSString **handleOut
) {
    NSArray<NSValue *> *ranges =
        NTYTExactPathRanges(
            bytes,
            length,
            kNTYTChannelMetadataPath,
            sizeof(kNTYTChannelMetadataPath) /
                sizeof(kNTYTChannelMetadataPath[0])
        );

    if (ranges.count != 1) {
        return;
    }

    NSRange range =
        ranges.firstObject.rangeValue;

    NSArray<NSString *> *channelIDs =
        NTYTDirectStringsForField(
            bytes,
            range.location,
            NSMaxRange(range),
            2
        );

    NSMutableArray<NSString *> *validChannelIDs =
        [NSMutableArray array];

    for (NSString *candidate in channelIDs) {
        if (NTYTIsChannelID(candidate)) {
            [validChannelIDs addObject:candidate];
        }
    }

    NSArray<NSString *> *handles =
        NTYTDirectStringsForField(
            bytes,
            range.location,
            NSMaxRange(range),
            4
        );

    if (
        channelIDOut &&
        validChannelIDs.count == 1
    ) {
        *channelIDOut =
            validChannelIDs.firstObject;
    }

    if (
        handleOut &&
        handles.count == 1
    ) {
        *handleOut =
            handles.firstObject;
    }
}


#pragma mark - display view count

/*
 * Observed on 22/22 normal-video samples.
 *
 * This path returns the UI-formatted display string such as:
 *
 *   4,555回視聴
 *   34万回視聴
 *   1.6万回視聴
 *
 * It is NOT an exact numeric view count.
 */
static const uint32_t kNTYTViewCountTextPath[] = {
    1,
    168777401,
    5,
    232954548,
    18,
    4,
    169495254,
    462702848,
    1,
    200453700,
    1,
    48687757,
    128119224,
    128400768,
    1,
    7,
    51779735,
    1,
    49399797,
    1,
    216561405,
    1,
    218178449,
    2,
    3,
    75730170,
    2
};


static NSString *NTYTExtractViewCountText(
    const uint8_t *bytes,
    NSUInteger length
) {
    NSArray<NSValue *> *ranges =
        NTYTExactPathRanges(
            bytes,
            length,
            kNTYTViewCountTextPath,
            sizeof(kNTYTViewCountTextPath) /
                sizeof(kNTYTViewCountTextPath[0])
        );

    NSMutableOrderedSet<NSString *> *values =
        [NSMutableOrderedSet orderedSet];

    for (NSValue *value in ranges) {
        NSRange range =
            value.rangeValue;

        NSString *text =
            NTYTUTF8String(
                bytes,
                range.location,
                range.length
            );

        if (text.length != 0) {
            [values addObject:text];
        }
    }

    return values.count == 1
        ? values.firstObject
        : nil;
}


#pragma mark - Public API

NTYTVideoMetadata *NTYTVideoMetadataFromElementData(
    NSData *data
) {
    if (
        ![data isKindOfClass:NSData.class] ||
        data.length == 0
    ) {
        return nil;
    }

    const uint8_t *bytes =
        data.bytes;

    NSUInteger length =
        data.length;

    if (!bytes) {
        return nil;
    }

    NSString *videoID =
        NTYTPrimaryVideoID(
            bytes,
            length
        );

    /*
     * Fail closed:
     * if the independently validated 73080600 video_id is absent or
     * ambiguous, do not pretend this payload was successfully decoded.
     *
     * This deliberately lets unsupported variants (for example a
     * previously observed special/live-like cell) pass through.
     */
    if (!videoID) {
        return nil;
    }

    NSString *title = nil;
    NSString *channelName = nil;

    NTYTExtractRichMetadata(
        bytes,
        length,
        videoID,
        &title,
        &channelName
    );

    NSString *channelID = nil;
    NSString *handle = nil;

    NTYTExtractChannelMetadata(
        bytes,
        length,
        &channelID,
        &handle
    );

    NSString *viewCountText =
        NTYTExtractViewCountText(
            bytes,
            length
        );

    NTYTVideoMetadata *metadata =
        [NTYTVideoMetadata new];

    metadata.videoID =
        videoID;

    metadata.title =
        title;

    metadata.channelID =
        channelID;

    metadata.channelName =
        channelName;

    metadata.handle =
        handle;

    metadata.viewCountText =
        viewCountText;

    return metadata;
}


NTYTVideoMetadata *NTYTVideoMetadataFromRenderer(
    YTIElementRenderer *renderer
) {
    if (!renderer) {
        return nil;
    }

    NSData *data = nil;

    @try {
        data =
            [renderer elementData];
    }
    @catch (__unused NSException *exception) {
        return nil;
    }

    if (
        ![data isKindOfClass:NSData.class] ||
        data.length == 0
    ) {
        return nil;
    }

    return NTYTVideoMetadataFromElementData(
        data
    );
}
