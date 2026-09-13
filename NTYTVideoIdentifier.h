#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class YTIElementRenderer;

@interface NTYTVideoMetadata : NSObject

@property (nonatomic, copy, readonly) NSString *videoID;
@property (nonatomic, copy, readonly, nullable) NSString *title;
@property (nonatomic, copy, readonly, nullable) NSString *channelID;
@property (nonatomic, copy, readonly, nullable) NSString *channelName;
@property (nonatomic, copy, readonly, nullable) NSString *handle;
@property (nonatomic, copy, readonly, nullable) NSString *viewCountText;

@end

FOUNDATION_EXPORT NTYTVideoMetadata * _Nullable
NTYTVideoMetadataFromElementData(NSData *data);

FOUNDATION_EXPORT NTYTVideoMetadata * _Nullable
NTYTVideoMetadataFromRenderer(YTIElementRenderer *renderer);

NS_ASSUME_NONNULL_END
