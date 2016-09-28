/*
 * Copyright (c) StreetHawk, All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3.0 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library.
 */

#import "SHApp+Feed.h"
//header from StreetHawk
#import "SHHTTPSessionManager.h" //for sending request
#import "SHFeedBridge.h" //for APPSTATUS_FEED_FETCH_TIME
#import "SHUtils.h" //for streetHawkIsEnabled
#import "SHLogger.h" //for sending logline
//header from System
#import <objc/runtime.h> //for associate object

@implementation SHApp (FeedExt)

#pragma mark - properties

@dynamic newFeedHandler;

- (void)setNewFeedHandler:(SHNewFeedsHandler)newFeedHandler
{
    objc_setAssociatedObject(self, @selector(newFeedHandler), newFeedHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (SHNewFeedsHandler)newFeedHandler
{
    return objc_getAssociatedObject(self, @selector(newFeedHandler));
}

#pragma mark - public functions

- (void)feed:(NSInteger)offset withHandler:(SHFeedsFetchHandler)handler
{
    if (!streetHawkIsEnabled())
    {
        return;
    }
    if (shStrIsEmpty(StreetHawk.currentInstall.suid))
    {
        SHLog(@"Warning: Fetch feeds must have install id.");
        if (handler)
        {
            NSError *error = [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"Parameter installid needed to determine Install."}];
            handler(nil, error);
        }
        return;
    }
    //update local cache time before send request, because this request has same format as others {app_status:..., code:0, value:...}, it will trigger `setFeedTimestamp` again. If fail to get request, clear local cache time in callback handler, make next fetch happen.
    BOOL needSet = NO;
    NSObject *localTimeVal = [[NSUserDefaults standardUserDefaults] objectForKey:APPSTATUS_FEED_FETCH_TIME];
    if (localTimeVal == nil || ![localTimeVal isKindOfClass:[NSNumber class]])
    {
        needSet = YES;
    }
    else
    {
        double localTime = [(NSNumber *)localTimeVal doubleValue];
        if (localTime < [[NSDate date] timeIntervalSinceReferenceDate] + 60)
        {
            needSet = YES;
        }
    }
    if (needSet)
    {
        [[NSUserDefaults standardUserDefaults] setObject:@([[NSDate date] timeIntervalSinceReferenceDate] + 60/*by testing server side is faster than client side time sometimes, add one minutes*/) forKey:APPSTATUS_FEED_FETCH_TIME];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    handler = [handler copy];
    [[SHHTTPSessionManager sharedInstance] GET:@"/feed/" hostVersion:SHHostVersion_V1 parameters:@{@"offset": @(offset)} success:^(NSURLSessionDataTask * _Nullable task, id  _Nullable responseObject)
    {
        NSMutableArray *arrayFeeds = [NSMutableArray array];
        NSError *error = nil;
        NSAssert([responseObject isKindOfClass:[NSArray class]], @"Feed result should be array, got %@.", responseObject);
        if ([responseObject isKindOfClass:[NSArray class]])
        {
            for (id obj in (NSArray *)responseObject)
            {
                NSAssert([obj isKindOfClass:[NSDictionary class]], @"Feed item should be dictionary, got %@.", obj);
                if ([obj isKindOfClass:[NSDictionary class]])
                {
                    SHFeedObject *feedObj = [SHFeedObject createFromDictionary:(NSDictionary *)obj];
                    [arrayFeeds addObject:feedObj];
                }
            }
        }
        else
        {
            error = [NSError errorWithDomain:SHErrorDomain code:INT_MIN userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Feed result should be array, got %@.", responseObject]}];
        }
        if (handler)
        {
            handler(arrayFeeds, error);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error)
    {
        [[NSUserDefaults standardUserDefaults] setObject:@(0) forKey:APPSTATUS_FEED_FETCH_TIME]; //make next fetch happen as this time fail.
        [[NSUserDefaults standardUserDefaults] synchronize];
        if (handler)
        {
            handler(nil, error);
        }
    }];
}

- (void)sendFeedAck:(NSString *)feed_id
{
    [self sendLogForCode:LOG_CODE_FEED_ACK withComment:[NSString stringWithFormat:@"Read feed %@.", feed_id] forAssocId:feed_id withResult:100 withHandler:nil];
}

- (void)notifyFeedResult:(NSString *)feed_id withResult:(SHResult)result
{
    [self notifyFeedResult:feed_id withResult:result withStepId:nil deleteFeed:NO completed:NO];
}

- (void)notifyFeedResult:(NSString *)feed_id withResult:(SHResult)result withStepId:(NSString *)stepId deleteFeed:(BOOL)feedDelete completed:(BOOL)complete
{
    NSString *resultStr = nil;
    NSInteger resultVal = 100;
    switch (result)
    {
        case SHResult_Accept:
        {
            resultStr = @"“accepted";
            resultVal = LOG_RESULT_ACCEPT;
            break;
        }
        case SHResult_Postpone:
        {
            resultStr = @"postponed";
            resultVal = LOG_RESULT_LATER;
            break;
        }
        case SHResult_Decline:
        {
            resultStr = @"rejected";
            resultVal = LOG_RESULT_CANCEL;
            break;
        }
        default:
            NSAssert(NO, @"Unkown feed result meet.");
            resultStr = @"“accepted";
            resultVal = LOG_RESULT_ACCEPT;
            break;
    }
    NSMutableDictionary *dictResult = [NSMutableDictionary dictionary];
    dictResult[@"status"] = resultStr;
    dictResult[@"feed_delete"] = @(feedDelete);
    dictResult[@"complete"] = @(complete);
    if (!shStrIsEmpty(stepId))
    {
        dictResult[@"step_id"] = stepId;
    }
    [StreetHawk sendLogForCode:LOG_CODE_FEED_RESULT withComment:shSerializeObjToJson(dictResult) forAssocId:feed_id withResult:resultVal withHandler:nil];
}

@end
