//
//  DBASRKit.h
//  SherpaNcnn
//
//  Created by 林喜 on 2023/4/25.
//

#import <Foundation/Foundation.h>
#import "c-api.h"


NS_ASSUME_NONNULL_BEGIN

@interface DBOfflineRecognizerConfig : NSObject

+ (SherpaNcnnModelConfig)configEncoderParam:(NSString *)encoderParam
                                 encoderBin:(NSString *)encoderBin
                               decoderParam:(NSString *)decoderParam
                                 decoderBin:(NSString *)decoderBin
                                joinerParam:(NSString *)joinerParam
                                  joinerBin:(NSString *)joinerBin
                                     tokens:(NSString *)tokens
                                 numThreads:(NSInteger)numThreads
                            useVulkanComute:(BOOL)useVulkanComute;


+ (SherpaNcnnFeatureExtractorConfig)configWithSampleRate:(Float64)sampleRate featureDim:(int)featureDim;

+ (SherpaNcnnDecoderConfig)decoderConfig:(NSString *)decodingMethod
                           numActivPaths:(int)numActivepPaths;

+ (SherpaNcnnRecognizerConfig)featConfig:(SherpaNcnnFeatureExtractorConfig)featConfig
                             modelConfig:(SherpaNcnnModelConfig)modelConfig
                           decoderConfig:(SherpaNcnnDecoderConfig)decoderConfig
                          enableEndpoint:(BOOL)enableEndPoint
                 rule1MinTrailingSilence:(float)rule1MinTrailingSilence
                  rule2MinTrailingSilence:(float)rule2MinTrailingSilence
                rule3MinTrainlingSilence:(float)rule3MinTrailingSilence ;

@end


NS_ASSUME_NONNULL_END
