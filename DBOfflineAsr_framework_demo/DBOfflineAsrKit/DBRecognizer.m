//
//  DBRecognizer.m
//  SherpaNcnn
//
//  Created by 林喜 on 2023/4/26.
//

#import "DBRecognizer.h"
#import "DBRecognitionResult.h"
#import "DBOfflineAsrUtil.h"
#import "DBLogManager.h"

@interface DBRecognizer ()
{
    SherpaNcnnRecognizer * _recognizer;
    SherpaNcnnStream *_stream;
}

@end

@implementation DBRecognizer

- (instancetype)initWithConfig:(SherpaNcnnRecognizerConfig)config {
    if (self = [super init]){
        _recognizer = CreateRecognizer(&config);
        _stream = CreateStream(_recognizer);
    }
    return self;
}

- (void)dealloc {
    if(_stream) {
        DestroyStream(_stream);
    }
    if(_recognizer) {
        DestroyRecognizer(_recognizer);
    }
}

- (void)acceptWaveFormSamples:(const float *)samples
                     samplesN:(int32_t)sample_n
                   smapleRate:(float)sampleRate {
    

    
    if (sampleRate > 48000 || sampleRate < 8000) {
        sampleRate = 16000;
    }
    AcceptWaveform(_stream, sampleRate, samples, sample_n);
    
}

- (BOOL)isReady {
    return IsReady(_recognizer, _stream);
}

- (void)decode {
    Decode(_recognizer, _stream);
}

- (DBRecognitionResult *)getResult {
    SherpaNcnnResult * result = GetResult(_recognizer, _stream);
    DBRecognitionResult *dbResult = [[DBRecognitionResult alloc] init];
    [dbResult setResult:result];
    return dbResult;
}

- (void)reset {
    DBLog(@"%@",TagInfo);
    Reset(_recognizer, _stream);
}

- (void)inputFinished {
    InputFinished(_stream);
}

- (bool)isEndpoint {
    return IsEndpoint(_recognizer, _stream) == 1;
}


@end
