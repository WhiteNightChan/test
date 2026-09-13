#import "NTYTRuleEvaluationContext.h"

@implementation NTYTRuleEvaluationContext

- (instancetype)initWithVideoID:(NSString *)videoID
                          title:(NSString *)title
                      channelID:(NSString *)channelID
                    channelName:(NSString *)channelName
                         handle:(NSString *)handle
                  viewCountText:(NSString *)viewCountText
                approxViewCount:(NSNumber *)approxViewCount
                        isVideo:(NSNumber *)isVideo
                        isShort:(NSNumber *)isShort
               videoDescription:(NSString *)videoDescription
                           tags:(NSArray<NSString *> *)tags
                         isLive:(NSNumber *)isLive
                       isMember:(NSNumber *)isMember {
    self = [super init];

    if (self) {
        _videoID = [videoID copy];
        _title = [title copy];
        _channelID = [channelID copy];
        _channelName = [channelName copy];
        _handle = [handle copy];
        _viewCountText = [viewCountText copy];
        _approxViewCount = [approxViewCount copy];
        _isVideo = [isVideo copy];
        _isShort = [isShort copy];
        _videoDescription = [videoDescription copy];
        _tags = [tags copy];
        _isLive = [isLive copy];
        _isMember = [isMember copy];
    }

    return self;
}

+ (instancetype)videoContextWithVideoID:(NSString *)videoID
                                  title:(NSString *)title
                              channelID:(NSString *)channelID
                            channelName:(NSString *)channelName
                                 handle:(NSString *)handle
                          viewCountText:(NSString *)viewCountText
                                isShort:(NSNumber *)isShort {
    return [[self alloc]
        initWithVideoID:videoID
        title:title
        channelID:channelID
        channelName:channelName
        handle:handle
        viewCountText:viewCountText
        approxViewCount:nil
        isVideo:@YES
        isShort:isShort
        videoDescription:nil
        tags:nil
        isLive:nil
        isMember:nil];
}

@end
