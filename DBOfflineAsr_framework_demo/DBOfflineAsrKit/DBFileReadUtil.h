//
//  DBFileReadUtil.h
//  DBAudioSDKDemo
//
//  Created by linxi on 2021/11/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@protocol DBFileReaderDelegate <NSObject>

/// 返回读取的数据
/// @param data 音频数据
/// @param endFlag  0: 第一包 1: 中间包 2: 最后一包
- (void)readData:(NSData *)data  endFlag:(NSInteger)endFlag;

/// 错误信息描述
/// @param code 错误码
/// @param msg 错误信息
- (void)readFileErrorCode:(NSString *)code msg:(NSString *)msg;


/// 打印信息
/// @param message 打印信息
- (void)logMessage:(NSString *)message;

@optional
- (void)acceptWaveFormSamples:(const float *)samples
                     samplesN:(int32_t)sample_n
                 smapleRate:(float)sampleRate;

@end

@interface DBFileReadUtil : NSObject

@property(nonatomic,weak)id <DBFileReaderDelegate> delegate;

/// 开始读取本地文件
- (void)startReadWithPath:(NSString *)filePath;

// 读取Wave文件
- (void)startReadWithWavePath:(NSString *)filePath;

//读取本地的pcm的数据
- (void)readPcmDataWithPath:(NSString *)path;

// 停止读取
- (void)stopRead;

// 保存录音文件
+ (void)saveAudioData:(NSString *)path data:(NSData *)data;


@end

NS_ASSUME_NONNULL_END
