#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NTYTRuleEvaluationContext : NSObject

@property (nonatomic, copy, readonly, nullable) NSString *videoID;
@property (nonatomic, copy, readonly, nullable) NSString *title;
@property (nonatomic, copy, readonly, nullable) NSString *channelID;
@property (nonatomic, copy, readonly, nullable) NSString *channelName;
@property (nonatomic, copy, readonly, nullable) NSString *handle;

@property (nonatomic, copy, readonly, nullable) NSString *viewCountText;
@property (nonatomic, copy, readonly, nullable) NSNumber *approxViewCount;

@property (nonatomic, copy, readonly, nullable) NSNumber *isVideo;
@property (nonatomic, copy, readonly, nullable) NSNumber *isShort;
@property (nonatomic, copy, readonly, nullable) NSString *videoDescription;
@property (nonatomic, copy, readonly, nullable) NSArray<NSString *> *tags;
@property (nonatomic, copy, readonly, nullable) NSNumber *isLive;
@property (nonatomic, copy, readonly, nullable) NSNumber *isMember;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithVideoID:(nullable NSString *)videoID
                          title:(nullable NSString *)title
                      channelID:(nullable NSString *)channelID
                    channelName:(nullable NSString *)channelName
                         handle:(nullable NSString *)handle
                  viewCountText:(nullable NSString *)viewCountText
                approxViewCount:(nullable NSNumber *)approxViewCount
                        isVideo:(nullable NSNumber *)isVideo
                        isShort:(nullable NSNumber *)isShort
               videoDescription:(nullable NSString *)videoDescription
                           tags:(nullable NSArray<NSString *> *)tags
                         isLive:(nullable NSNumber *)isLive
                       isMember:(nullable NSNumber *)isMember
    NS_DESIGNATED_INITIALIZER;

// Convenience factory for the currently supported standalone video path.
// isVideo is always YES. isShort can be YES/NO when the caller knows it,
// otherwise nil means UNKNOWN.
+ (instancetype)videoContextWithVideoID:(nullable NSString *)videoID
                                  title:(nullable NSString *)title
                              channelID:(nullable NSString *)channelID
                            channelName:(nullable NSString *)channelName
                                 handle:(nullable NSString *)handle
                          viewCountText:(nullable NSString *)viewCountText
                                isShort:(nullable NSNumber *)isShort;

@end

NS_ASSUME_NONNULL_END
