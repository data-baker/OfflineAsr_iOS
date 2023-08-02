//
//  DBAsrDelegate.h
//  DBOfflineAsrKit
//
//  Created by 林喜 on 2023/4/28.
//

#ifndef DBAsrDelegate_h
#define DBAsrDelegate_h

@protocol DBAsrDelegate <NSObject>

/// 识别结果回调 message为识别内容 sentenceEnd为是否一句话结束(不是识别结束,还可以继续识别)
- (void)identifyTheCallback:(NSString *)message sentenceEnd:(BOOL)sentenceEnd;

/// 音频分贝值回调
- (void)dbValues:(NSInteger)db;

/// 错误回调 code:错误码  message:错误信息
- (void)onError:(NSInteger)code message:(NSString *)message;

@end


#endif /* DBAsrDelegate_h */
