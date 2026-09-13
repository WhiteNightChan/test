#import "NTYTRuleTypes.h"

NSErrorDomain const NTYTRuleModelErrorDomain = @"com.nothankyoutubetweak.rulemodel";

NSString *NTYTStringFromField(NTYTField field) {
    switch (field) {
        case NTYTFieldGeneralText:
            return @"general_text";
        case NTYTFieldContentText:
            return @"content_text";
        case NTYTFieldVideoText:
            return @"video_text";
        case NTYTFieldVideoID:
            return @"video_id";
        case NTYTFieldChannelIdentity:
            return @"channel_identity";
        case NTYTFieldIsVideo:
            return @"is_video";
        case NTYTFieldIsShort:
            return @"is_short";
        case NTYTFieldViewCount:
            return @"view_count";
        case NTYTFieldDescription:
            return @"description";
        case NTYTFieldTags:
            return @"tags";
        case NTYTFieldIsLive:
            return @"is_live";
        case NTYTFieldIsMember:
            return @"is_member";
        case NTYTFieldUnknown:
        default:
            return @"unknown";
    }
}

NTYTField NTYTFieldFromString(NSString *string) {
    if (![string isKindOfClass:[NSString class]]) {
        return NTYTFieldUnknown;
    }

    if ([string isEqualToString:@"general_text"]) {
        return NTYTFieldGeneralText;
    }
    if ([string isEqualToString:@"content_text"]) {
        return NTYTFieldContentText;
    }
    if ([string isEqualToString:@"video_text"]) {
        return NTYTFieldVideoText;
    }
    if ([string isEqualToString:@"video_id"]) {
        return NTYTFieldVideoID;
    }
    if ([string isEqualToString:@"channel_identity"]) {
        return NTYTFieldChannelIdentity;
    }
    if ([string isEqualToString:@"is_video"]) {
        return NTYTFieldIsVideo;
    }
    if ([string isEqualToString:@"is_short"]) {
        return NTYTFieldIsShort;
    }
    if ([string isEqualToString:@"view_count"]) {
        return NTYTFieldViewCount;
    }
    if ([string isEqualToString:@"description"]) {
        return NTYTFieldDescription;
    }
    if ([string isEqualToString:@"tags"]) {
        return NTYTFieldTags;
    }
    if ([string isEqualToString:@"is_live"]) {
        return NTYTFieldIsLive;
    }
    if ([string isEqualToString:@"is_member"]) {
        return NTYTFieldIsMember;
    }

    return NTYTFieldUnknown;
}

NSString *NTYTStringFromMatcher(NTYTMatcher matcher) {
    switch (matcher) {
        case NTYTMatcherContains:
            return @"contains";
        case NTYTMatcherExact:
            return @"exact";
        case NTYTMatcherRegex:
            return @"regex";
        case NTYTMatcherBoolean:
            return @"boolean";
        case NTYTMatcherLessThan:
            return @"less_than";
        case NTYTMatcherLessThanOrEqual:
            return @"less_than_or_equal";
        case NTYTMatcherGreaterThan:
            return @"greater_than";
        case NTYTMatcherGreaterThanOrEqual:
            return @"greater_than_or_equal";
        case NTYTMatcherUnknown:
        default:
            return @"unknown";
    }
}

NTYTMatcher NTYTMatcherFromString(NSString *string) {
    if (![string isKindOfClass:[NSString class]]) {
        return NTYTMatcherUnknown;
    }

    if ([string isEqualToString:@"contains"]) {
        return NTYTMatcherContains;
    }
    if ([string isEqualToString:@"exact"]) {
        return NTYTMatcherExact;
    }
    if ([string isEqualToString:@"regex"]) {
        return NTYTMatcherRegex;
    }
    if ([string isEqualToString:@"boolean"]) {
        return NTYTMatcherBoolean;
    }
    if ([string isEqualToString:@"less_than"]) {
        return NTYTMatcherLessThan;
    }
    if ([string isEqualToString:@"less_than_or_equal"]) {
        return NTYTMatcherLessThanOrEqual;
    }
    if ([string isEqualToString:@"greater_than"]) {
        return NTYTMatcherGreaterThan;
    }
    if ([string isEqualToString:@"greater_than_or_equal"]) {
        return NTYTMatcherGreaterThanOrEqual;
    }

    return NTYTMatcherUnknown;
}

NSString *NTYTStringFromOptionOverride(NTYTOptionOverride value) {
    switch (value) {
        case NTYTOptionOverrideForceOn:
            return @"force_on";
        case NTYTOptionOverrideForceOff:
            return @"force_off";
        case NTYTOptionOverrideInherit:
        default:
            return @"inherit";
    }
}

BOOL NTYTOptionOverrideFromObject(
    id object,
    NTYTOptionOverride *outValue
) {
    if (!outValue) {
        return NO;
    }

    if (object == nil || object == [NSNull null]) {
        *outValue = NTYTOptionOverrideInherit;
        return YES;
    }

    if (![object isKindOfClass:[NSString class]]) {
        return NO;
    }

    NSString *string = (NSString *)object;

    if ([string isEqualToString:@"inherit"]) {
        *outValue = NTYTOptionOverrideInherit;
        return YES;
    }
    if ([string isEqualToString:@"force_on"]) {
        *outValue = NTYTOptionOverrideForceOn;
        return YES;
    }
    if ([string isEqualToString:@"force_off"]) {
        *outValue = NTYTOptionOverrideForceOff;
        return YES;
    }

    return NO;
}
