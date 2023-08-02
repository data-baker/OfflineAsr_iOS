//
//  DBOfflineAsrClient.h
//  DBOfflineAsrKit
//
//  Created by 林喜 on 2023/5/4.
//

#import <Foundation/Foundation.h>
#import "DBAsrDelegate.h"

typedef void (^DBMessagHandler)(NSInteger ret, NSString * _Nullable message);
NS_ASSUME_NONNULL_BEGIN

@interface DBOfflineAsrClient : NSObject

/// 1.打印日志打同时会在沙盒中保存一份日志记录（默认为Yes） 0:不打印日志
@property(nonatomic,assign)BOOL isLog;

// 获取Asr识别的单例对象
+ (instancetype)shareInstance;

// 设置Asr的回调代理对象
@property(nonatomic,weak)id <DBAsrDelegate> delegate;

// 设置离线Asr的授权, messageHandler中，ret = 0表示授权成功， 否则为授权失败，message表示授权后所拿到的信息
- (void)setupRecognizerClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret messageHander:(DBMessagHandler)messageHandler;

// 设置合成需要的离线模型参数，模型文件请联系标贝科技获取，numberOfThread表示默认使用的CPU核，默认为单核，最高为6核
- (void)setupRecognizerWithEncoderParam:(NSString *)encoderParam
                             encoderBin:(NSString *)encoderBin
                           decoderParam:(NSString *)decoderParam
                             decoderBin:(NSString *)decoderBin
                            joinerParam:(NSString *)joinerParam
                              joinerBin:(NSString *)joinerBin
                                 tokens:(NSString *)tokens
                         numberOfThread:(NSInteger)numberOfThread;
// 开启Asr
- (BOOL)startAsr;

// 关闭Asr
- (void)stopAsr;

// 开启文件识别，需要传入文件的路径
- (BOOL)startAsrWithFilePath:(NSString *)filePath;

// 结束文件识别
- (void)stopFileRecognize;

// Test method
- (void)clearAuth;

- (void)logMessage:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
