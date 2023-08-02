//
//  DBNetworkHelper.h
//
//  Created by linxi on 2019/11/14.
//  Copyright © 2019 biaobei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#define DevelopSever 1
#define Release_UAT_Sever 0
#define ProductSever 0

/// 测试环境
#if DevelopSever
// 鹏飞电脑的地址
#define DBOfflineAuthUrl  @"http://10.10.50.23:9904/statistic/uid/server/time"
#define getTokenURL @"http://10.10.50.23:9904/oauth/2.0/token"

// 沙盒环境（当前沙盒环境未启用）
#elif Release_UAT_Sever

#elif ProductSever
#define DBOfflineAuthUrl  @"https://openapi.data-baker.com/statistic/uid/server/time"
#define getTokenURL @"https://openapi.data-baker.com/oauth/2.0/token"
#endif

// 通知相关逻辑
static NSString *const DBNetworkRefreshToken =@"DBNetworkRefreshToken";
static NSString * const networkErrorDomain = @"DBNetworkErrorDomain";

typedef void (^DBSuccessBlock)(NSDictionary * __nullable data);
typedef void (^DBSuccessDataBlock)(NSData * __nullable data);
typedef void (^DBFailureBlock)(NSError * __nullable error);

@protocol DBNetworkUpdateInfoAction <NSObject>

- (void)updateToken:(NSString *)token;

@end


@interface DBASRNetworkHelper : NSObject

@property(nonatomic,weak)id<DBNetworkUpdateInfoAction>  delegate;


+ (instancetype)shareInstance;

/**
 *  get请求
 */
- (void)getWithUrlString:(NSString *)url parameters:(id)parameters success:(DBSuccessBlock)successBlock failure:(DBFailureBlock)failureBlock;


/**
 *  get请求,请求合成的音频数据
 */
- (void)getAudioDataWithUrlString:(NSString *)url parameters:(NSDictionary *)parameters success:(DBSuccessDataBlock)successBlock failure:(DBFailureBlock)failureBlock;

/**
 * post请求,
 */
- (void)postWithUrlString:(NSString * __nullable)url headerDict:(NSDictionary *)headerParameters parameters:( id __nullable)parameters success:(DBSuccessBlock)successBlock failure:(DBFailureBlock)failureBlock;

@end

NS_ASSUME_NONNULL_END
