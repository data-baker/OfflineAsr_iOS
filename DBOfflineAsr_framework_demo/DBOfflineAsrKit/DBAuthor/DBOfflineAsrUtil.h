//
//  DBOfflineTransferVoiceClient.h
//  DBAudioSDKDemo
//
//  Created by linxi on 2021/10/26.
//

#import <Foundation/Foundation.h>

// ret: 0 表示授权成功
typedef void (^DBMessagHandler)(NSInteger ret, NSString * _Nullable message);

NS_ASSUME_NONNULL_BEGIN

#define KAsrUtil [DBOfflineAsrUtil shareInstance]

#define KOfflineASRVersion @"1.0.0"

@interface DBOfflineAsrUtil : NSObject

/// 1.打印日志 0:不打印日志(打印日志会在沙盒中保存一份text,方便我们查看,上线前要置为NO);
@property (nonatomic, assign) BOOL log;

///  示例化方法
+ (instancetype)shareInstance;
///  初始化SDK
- (void)setupOfflineAsrSDKClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret messageHander:(DBMessagHandler)messageHandler;

- (void)clearAuth;

void writeLog(const char * format,...);


@end

NS_ASSUME_NONNULL_END
