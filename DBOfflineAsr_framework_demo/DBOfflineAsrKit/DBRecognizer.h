//
//  DBRecognizer.h
//  SherpaNcnn
//
//  Created by 林喜 on 2023/4/26.
//

#import <Foundation/Foundation.h>
#import "c-api.h"
#import "DBRecognitionResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface DBRecognizer : NSObject

- (instancetype)initWithConfig:(SherpaNcnnRecognizerConfig)config;

- (void)acceptWaveFormSamples:(const float *)samples
                     samplesN:(int32_t)sample_n
                   smapleRate:(float)sampleRate;

- (BOOL)isReady;

- (void)decode;

- (void)reset;

- (void)inputFinished;

- (bool)isEndpoint;

- (DBRecognitionResult *)getResult;

@end

NS_ASSUME_NONNULL_END
