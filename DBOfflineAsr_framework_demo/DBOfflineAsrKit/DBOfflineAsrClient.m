//
//  DBOfflineAsrClient.m
//  DBOfflineAsrKit
//
//  Created by 林喜 on 2023/5/4.
//

#import "DBOfflineAsrClient.h"
#import <AVFoundation/AVFoundation.h>
#import "DBRecognizer.h"
#import "DBRecognitionResult.h"
#import "DBOfflineAsrUtil.h"
#import "DBFileReadUtil.h"
#import "DBOfflineRecognizerConfig.h"
#import "DBLogManager.h"

#define kDBOffset 100.0 // 20 * log10(1.0 / 32767.0)：参考值为32767时的分贝偏移量

@interface DBOfflineAsrClient ()<DBFileReaderDelegate>
{
    NSMutableData *_reqData;
    NSString *_filePath;
}
///  离线Asr识别的回调和SDK的记录
@property(nonatomic,strong)AVAudioEngine  * audioEngine;
@property(nonatomic,strong)DBRecognizer   * recognizer;
@property(nonatomic,strong)DBFileReadUtil * fileReadUtil;
/// 是否经过授权
@property(nonatomic,assign)BOOL isAuthored;
@end

@implementation DBOfflineAsrClient

+ (instancetype)shareInstance {
    static DBOfflineAsrClient *client = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        client = [[DBOfflineAsrClient alloc]init];
        client->_reqData = [NSMutableData data];
        client.isLog = YES;
        client.isAuthored = NO;
    });
    return client;
}
// MARK: Public Method

- (void)setupRecognizerClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret messageHander:(DBMessagHandler)messageHandler {
    NSAssert(messageHandler, @"请设置授权回调的messageHandler");
    DBLog(@"%@clientIt:%@,clientSecret:%@",TagInfo,clientId,clientSecret);
    self.isAuthored = NO;
    [KAsrUtil setupOfflineAsrSDKClientId:clientId clientSecret:clientSecret messageHander:^(NSInteger ret, NSString * _Nullable message) {
        if (ret == 0) {
            self.isAuthored = YES;
        }
        messageHandler(ret,message);
    }];
}
- (void)clearAuth {
    DBLog(@"%@",TagInfo);
    [KAsrUtil clearAuth];
}

- (void)setIsLog:(BOOL)isLog {
    DBLog(@"%@",TagInfo);
    _isLog = isLog;
    KAsrUtil.log = isLog;
}

- (void)setDelegate:(id<DBAsrDelegate>)delegate {
    _delegate = delegate;
    DBLog(@"%@%@",TagInfo,delegate);
}

- (BOOL)startAsr {
    DBLog(@"%@",TagInfo);
    if(!_isAuthored) {
        DBLog(@"%@%@",TagError,@"没有授权");
        [self throwErrorWithErrorCode:114004 msg:@"授权失败"];
        return NO;
    }
    _reqData = [NSMutableData data];
    NSError *error;
    if(!self.audioEngine) {
        [self setupAudioEngine];
    }
    BOOL ret = [self.audioEngine startAndReturnError:&error];
    if (error) {
        DBLog(@"%@,error %@",TagError,error.description);
    }
    return ret;
}

- (void)stopAsr {
    DBLog(@"%@",TagInfo);
    [self.audioEngine stop];
    [_reqData writeToFile:[self filePath] atomically:YES];
}


// MARK: Private Method
- (void)setupAudioEngine {
    AVAudioEngine *engine = [[AVAudioEngine alloc]init];
    self.audioEngine = engine;
    AVAudioNode *inputNode = engine.inputNode;
    int bus = 0;
    AVAudioFormat * inputFormat = [inputNode outputFormatForBus:bus];
    AVAudioFormat *outputFormat = [[AVAudioFormat alloc]initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:16000 channels:1 interleaved:NO];
    AVAudioConverter *converter = [[AVAudioConverter alloc] initFromFormat:inputFormat toFormat:outputFormat];
    [inputNode installTapOnBus:bus bufferSize:1024 format:inputFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        __block  BOOL newBufferAvailable = YES;
        AVAudioConverterInputBlock inputCallback = ^AVAudioBuffer *(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus* outStatus) {
            if (newBufferAvailable) {
                *outStatus = AVAudioConverterInputStatus_HaveData;
                newBufferAvailable = NO;
                return buffer;
            }else {
                *outStatus = AVAudioConverterInputStatus_NoDataNow;
                return nil;
            }
        };
        
        AVAudioPCMBuffer *convertBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:outputFormat frameCapacity:(outputFormat.sampleRate * buffer.frameLength) / (buffer.format.sampleRate)];
        NSError *error;
        [converter convertToBuffer:convertBuffer error:&error withInputFromBlock:inputCallback];
        if (error) {
            DBLog(@"%@error :%@",TagError,error.description);
        }
        Float32 *   mBuffers= (Float32 *)convertBuffer.audioBufferList->mBuffers->mData;
        int mBuffersCount = convertBuffer.audioBufferList->mBuffers->mDataByteSize/ sizeof(Float32);
        if (mBuffersCount > 0) {
            [self->_reqData appendBytes:convertBuffer.audioBufferList->mBuffers->mData length:convertBuffer.audioBufferList->mBuffers->mDataByteSize];
            [self.recognizer acceptWaveFormSamples:mBuffers samplesN:mBuffersCount smapleRate:16000];
            [self parseRecognizeResult];
            [self dbValuesOfBuffer:mBuffers length:mBuffersCount];
        }
    }
    ];
}

- (void)dbValuesOfBuffer:(Float32 *)audio length:(UInt32)length {
    NSInteger value = calculatedBFromBuffer(audio, length);
    if (self.delegate && [self.delegate respondsToSelector:@selector(dbValues:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate dbValues:value];
        });
    }
}

int calculatedBFromBuffer(Float32 *audio, UInt32 length) {
    double sum = 0;
    for (int i = 0; i < length; i++) {
        sum += pow(audio[i], 2.0);
    }
    double rms = sqrt(sum / length);
    float value = 20 * log10(rms) + kDBOffset;
    return value;
}

- (void)parseRecognizeResult {
    while ([self.recognizer isReady]) {
        [self.recognizer decode];
    }
    BOOL endPoint = [self.recognizer isEndpoint];
    NSString *text = [[self.recognizer getResult] text];
    if (self.delegate && [self.delegate respondsToSelector:@selector(identifyTheCallback:sentenceEnd:)]) {
        [self.delegate identifyTheCallback:text sentenceEnd:endPoint];
    }
    if (endPoint) {
        DBLog(@"%@ text:%@ endPoint:%@",TagInfo,text,@(endPoint));
        [self.recognizer reset];
    }
}

- (void)setupRecognizerWithEncoderParam:(NSString *)encoderParam encoderBin:(NSString *)encoderBin decoderParam:(NSString *)decoderParam decoderBin:(NSString *)decoderBin joinerParam:(NSString *)joinerParam joinerBin:(NSString *)joinerBin tokens:(NSString *)tokens numberOfThread:(NSInteger)numberOfThread {
    if (_recognizer) {
        [_recognizer reset];
        _recognizer = nil;
        DBLog(@"%@%@",TagInfo,@"Reset Recognizer");
    }
    SherpaNcnnFeatureExtractorConfig featConfig = [DBOfflineRecognizerConfig configWithSampleRate:16000 featureDim:80];
    SherpaNcnnModelConfig modelConfig = [DBOfflineRecognizerConfig configEncoderParam:encoderParam encoderBin:encoderBin decoderParam:decoderParam decoderBin:decoderBin joinerParam:joinerParam joinerBin:joinerBin tokens:tokens numThreads:numberOfThread useVulkanComute:YES];
    SherpaNcnnDecoderConfig decoderConfig = [DBOfflineRecognizerConfig decoderConfig:@"modified_beam_search" numActivPaths:4];
    SherpaNcnnRecognizerConfig config = [DBOfflineRecognizerConfig featConfig:featConfig modelConfig:modelConfig decoderConfig:decoderConfig enableEndpoint:YES rule1MinTrailingSilence:1.2 rule2MinTrailingSilence:2.4 rule3MinTrainlingSilence:300];
    self.recognizer = [[DBRecognizer alloc] initWithConfig:config];
}


/// MARK: Call back 的错误处理
- (void)throwErrorWithErrorCode:(NSInteger)code msg:(NSString *)errorMsg {
    DBLog("error code :%ld messgae :%@",(long)code,errorMsg);
    if (self.delegate && [self.delegate respondsToSelector:@selector(onError:message:)]) {
        [self.delegate onError:code message:errorMsg];
    }
}

/// MARK： 文件识别
- (BOOL)startAsrWithFilePath:(NSString *)filePath {
    DBLog(@"%@ filePath:%@",TagInfo,filePath);
    if(!_isAuthored) {
        DBLog(@"%@%@",TagError,@"Not author");
        [self throwErrorWithErrorCode:114004 msg:@"授权失败"];
        return NO;
    }
    [self stopFileRecognize];
    [self.fileReadUtil readPcmDataWithPath:filePath];
    return YES;
}

-(void)stopFileRecognize {
    [self.recognizer reset];
    [self.fileReadUtil stopRead];
}

// MARK: DBFileReaderDelegate
- (void)readData:(NSData *)data endFlag:(NSInteger)endFlag {
    NSUInteger count = [data length] / sizeof(Float32);
    Float32 *buffer = (Float32 *)malloc(sizeof(Float32) * count);
    [data getBytes:buffer length:[data length]];
    [self dbValuesOfBuffer:buffer length:(UInt32)count];
    [self.recognizer acceptWaveFormSamples:buffer samplesN:(int32_t)count smapleRate:16000];
    [self parseRecognizeResult];
    DBLog(@"%@ Data length:%ld endFlag:%@",TagDebug,[data length],@(endFlag));
}


- (void)acceptWaveFormSamples:(const float *)samples
                     samplesN:(int32_t)sample_n
                   smapleRate:(float)sampleRate {
    [self.recognizer acceptWaveFormSamples:samples samplesN:sample_n smapleRate:sampleRate];
    [self parseRecognizeResult];
}


- (void)readFileErrorCode:(nonnull NSString *)code msg:(nonnull NSString *)msg {
    if ([self.delegate respondsToSelector:@selector(onError:message:)]) {
        [self.delegate onError:[code integerValue] message:msg];
    }
}
- (void)logMessage:(NSString *)message {
    DBLog(@"%@%@",TagInfo,message);
}


- (NSString *)filePath {
    if(!_filePath) {
        NSString *filePath = [NSString stringWithFormat:@"%@/req.pcm",NSTemporaryDirectory()];
        _filePath = filePath;
    }
    return _filePath;
}

- (DBFileReadUtil *)fileReadUtil {
    if (!_fileReadUtil) {
        _fileReadUtil = [[DBFileReadUtil alloc]init];
        _fileReadUtil.delegate = self;
    }
    return _fileReadUtil;
}


@end
