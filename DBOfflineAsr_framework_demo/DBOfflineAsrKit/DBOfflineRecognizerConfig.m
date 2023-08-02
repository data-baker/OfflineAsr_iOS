//
//  DBASRKit.m
//  SherpaNcnn
//
//  Created by 林喜 on 2023/4/25.
//

#import "DBOfflineRecognizerConfig.h"

@implementation DBOfflineRecognizerConfig

+ (SherpaNcnnModelConfig)configEncoderParam:(NSString *)encoderParam
  encoderBin:(NSString *)encoderBin
  decoderParam:(NSString *)decoderParam
    decoderBin:(NSString *)decoderBin
   joinerParam:(NSString *)joinerParam
     joinerBin:(NSString *)joinerBin
        tokens:(NSString *)tokens
    numThreads:(NSInteger)numThreads
useVulkanComute:(BOOL)useVulkanComute {
    SherpaNcnnModelConfig config = SherpaNcnnModelConfig();
    config.encoder_param =  encoderParam.UTF8String;
    config.encoder_bin = encoderBin.UTF8String;
    config.decoder_bin = decoderBin.UTF8String;
    config.decoder_param = decoderParam.UTF8String;
    config.joiner_param = joinerParam.UTF8String;
    config.joiner_bin = joinerBin.UTF8String;
    config.tokens = tokens.UTF8String;
    if (numThreads > 6 || numThreads < 1) {
        numThreads = 1;
    }
    config.num_threads = (int32_t)numThreads;
    config.use_vulkan_compute = useVulkanComute;
    return config;
}

+ (SherpaNcnnFeatureExtractorConfig)configWithSampleRate:(Float64)sampleRate featureDim:(int)featureDim {
    SherpaNcnnFeatureExtractorConfig config = SherpaNcnnFeatureExtractorConfig();
    config.sampling_rate = sampleRate;
    config.feature_dim = featureDim;
    return config;
}

+ (SherpaNcnnDecoderConfig)decoderConfig:(NSString *)decodingMethod
                           numActivPaths:(int)numActivepPaths {
    SherpaNcnnDecoderConfig decoderConfig = SherpaNcnnDecoderConfig();
    decoderConfig.decoding_method =  decodingMethod.UTF8String;
    decoderConfig.num_active_paths = numActivepPaths;
    return decoderConfig;
}

+ (SherpaNcnnRecognizerConfig)featConfig:(SherpaNcnnFeatureExtractorConfig)featConfig
                             modelConfig:(SherpaNcnnModelConfig)modelConfig
                           decoderConfig:(SherpaNcnnDecoderConfig)decoderConfig
                          enableEndpoint:(BOOL)enableEndPoint
                 rule1MinTrailingSilence:(float)rule1MinTrailingSilence
                  rule2MinTrailingSilence:(float)rule2MinTrailingSilence
                rule3MinTrainlingSilence:(float)rule3MinTrailingSilence {
    
    if (!rule1MinTrailingSilence) {
        rule1MinTrailingSilence = 2.4;
    }
    if (!rule2MinTrailingSilence) {
        rule2MinTrailingSilence = 1.2;
    }
    if (!rule3MinTrailingSilence) {
        rule3MinTrailingSilence = 30;
    }
    
    SherpaNcnnRecognizerConfig recognizerConfig = SherpaNcnnRecognizerConfig();
    recognizerConfig.feat_config = featConfig;
    recognizerConfig.model_config = modelConfig;
    recognizerConfig.decoder_config = decoderConfig;
    recognizerConfig.enable_endpoint = enableEndPoint;
    recognizerConfig.rule1_min_trailing_silence = rule1MinTrailingSilence;
    recognizerConfig.rule2_min_trailing_silence = rule2MinTrailingSilence;
    recognizerConfig.rule3_min_utterance_length = rule3MinTrailingSilence;
    return recognizerConfig;
}

@end
