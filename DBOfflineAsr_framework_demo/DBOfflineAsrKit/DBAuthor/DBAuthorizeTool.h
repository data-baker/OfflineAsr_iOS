//
//  DBAuthorizeTool.h
//  WebSocketDemo
//
//  Created by linxi on 2020/4/20.
//  Copyright © 2020 newbike. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger,DBDeviceActivityState) {
    DBDeviceActivityStateFirstSuccess = 0, // 首次激活成功
    DBDeviceActivityStateUpdateSuccess = 1, // 更新激活成功
    DBDeviceActivityStateInsufficient  = 2,// 激活数不够
    DBDeviceActivityStateTooMuch = 3, // 在一段时间内激活次数太多
    DBDeviceActivityStateNetworkFailed = 400 // 授权的网络请求失败
};

typedef NS_ENUM(NSUInteger,DBOffVCAuthError) {
    DBOffAuthErrorPara = 22190010, // 请求授权参数报错
    DBOffAuthErrorAccessToken = 22190011, // 获取token报错
    DBOffAuthErrorAuthFailed = 22190012, // 授权无效
    DBOffAuthErrorDeviceId = 22190013 // 设备信息鉴权失败

};
/// status： 1:激活成功，2:安装量不足 3：该UID在规定时间内校验次数超过限制
typedef void(^CompleteBlock)(NSString *deviceid, DBDeviceActivityState status);

/// ret， 0: 鉴权成功
typedef void (^DBMessagHandler)(NSInteger ret, NSString *message);

@interface DBAuthorizeTool : NSObject

// 当前是否有网络，YES:有网络，NO没有网络
+ (BOOL)isNetwork;

/// 获取设备的唯一标识
+ (NSString *)getLocalDeviceIdWithUserId:(NSString *)userId;

/// 生成设备的UUID
+ (NSString *)generateUUIDStringWithUserId:(NSString *)userId;

/// 判断用户是否可以使用离线合成
+ (BOOL)canUseOfflineSynthesisWithUserId:(NSString *)userId;

/// 本地的设备信息是否有效
+ (BOOL)isVaildAuthorWithUserId:(NSString *)userId;

// 网络请求整理获取安装的数据
+ (void)activeDevicesRequestWithHeaderParams:(NSDictionary *)headerParams messageHander:(DBMessagHandler)messageHandler;

/// 清除授权信息
+ (BOOL)clearKeyChainUids;



@end

NS_ASSUME_NONNULL_END
