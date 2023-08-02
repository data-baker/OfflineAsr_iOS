//
//  DBFileReadUtil.m
//  DBAudioSDKDemo
//
//  Created by linxi on 2021/11/1.
//

#import "DBFileReadUtil.h"
#include <vector>
#include <string>
#import "DBLogManager.h"

static  const NSUInteger kChunkLength = 640;

@interface DBFileReadUtil ()
@property(nonatomic,copy)NSString * filePath;
@property (nonatomic) NSUInteger hasReadFileSize;
@property (nonatomic) int sizeToRead;
@property (nonatomic, retain) NSFileHandle *fileHandle;
@property (nonatomic, retain) NSThread *fileReadThread;
/// 0: 首包 1: 中间包 2: 尾包
@property(nonatomic,assign)NSInteger dataFlag;

@end

@implementation DBFileReadUtil

- (void)startReadWithPath:(NSString *)filePath {
    self.filePath = filePath;
    self.sizeToRead = kChunkLength;
    self.hasReadFileSize = 0;
    self.dataFlag = 0;
    NSThread *fileReadThread = [[NSThread alloc] initWithTarget:self
                                                       selector:@selector(fileReadThreadFunc)
                                                         object:nil];
    self.fileReadThread = fileReadThread;
    [self.fileReadThread start];
}

- (void)startReadWithWavePath:(NSString *)filePath {
    self.hasReadFileSize = 44;
    [self startReadWithPath:filePath];
}

- (void)stopRead {
    self.hasReadFileSize = 0;
    if (self.fileReadThread) {
        DBLog(@"%@%@",TagInfo,@"Cancel file Read");
        [self.fileReadThread cancel];
        while (self.fileReadThread && ![self.fileReadThread isFinished])
        {
            [NSThread sleepForTimeInterval:0.1];
        }
    }
}

- (void)fileReadThreadFunc {
    NSAssert(self.delegate, @"请设置回调的的代理");
    while ([self.fileReadThread isCancelled] == NO) {
        // Mock human speech speed
        [NSThread sleepForTimeInterval:0.1];
        self.fileHandle = [NSFileHandle fileHandleForReadingAtPath:self.filePath];
        if (!self.fileHandle) {
            NSString *errMsg = [NSString stringWithFormat:@"File load failed with filePath:%@",self.filePath];
            [self logMessage:errMsg];
            DBLog(@"%@%@",TagError,errMsg);
            [self.fileReadThread cancel];
            [self delegateErrorCode:@"22190001" message:errMsg];
            return;
        }
        
        [self.fileHandle seekToFileOffset:self.hasReadFileSize];
        NSData* data = [self.fileHandle readDataOfLength:self.sizeToRead];
        [self.fileHandle closeFile];
        self.hasReadFileSize += [data length];
        if ([data length] < self.sizeToRead) {
            DBLog(@"%@%@",TagInfo,@"Finished read file");
            [self logMessage:@"文件读取完成"];
            if (self.dataFlag == 2) {
                if (data.length == 0) {
                    data = [NSMutableData dataWithLength:kChunkLength];
                }
                [self.delegate readData:data endFlag:-2];
            }
            [self stopRead];
            break;
        }else {
            if (self.dataFlag == 0) {
                [self.delegate readData:data endFlag:0];
                self.dataFlag = 1;
            }else {
                self.dataFlag = 2;
                [self.delegate readData:data endFlag:1];
            }
        }
    }
}

- (void)readPcmDataWithPath:(NSString *)path {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        DBLog(@"%@%@",TagDebug,path);
        std::vector<float> wave_data;
        std::string pcm_name =  [path cStringUsingEncoding:NSUTF8StringEncoding];
        Read_pcm(pcm_name,wave_data);
        [self.delegate acceptWaveFormSamples:&wave_data[0] samplesN:(int)wave_data.size() smapleRate:16000];
    });
}


void Read_pcm(std::string pcm_name,std::vector<float> &wave_data) {
    int16_t *speech = new int16_t[16000 * 1000];
    FILE *fp = fopen(pcm_name.c_str(), "rb");
    assert(NULL != fp);
    fseek(fp, 0, SEEK_END);
    int sample_length = (int)ftell(fp) / sizeof(int16_t);
    rewind(fp);
    fread(speech, sizeof(int16_t), sample_length, fp);
    fclose(fp);
    wave_data.resize(sample_length);
    for (int i = 0; i < sample_length; i++){
        wave_data[i] = float(speech[i] / 32768.0);
    }
    delete[] speech;
}

- (void)delegateErrorCode:(NSString *)code message:(NSString *)message {
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(readFileErrorCode:msg:)]) {
        [self.delegate readFileErrorCode:code msg:message];
    }
    
}

- (void)logMessage:(NSString *)message {
    if (self.delegate && [self.delegate respondsToSelector:@selector(logMessage:)] ) {
        [self.delegate logMessage:message];
    }
}

+ (void)saveAudioData:(NSString *)path data:(NSData *)data {
    NSString *filePath = path;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:filePath]) {
        NSString *fileName = [[path componentsSeparatedByString:@"/"] lastObject];
        NSString *dirPath = [path stringByReplacingOccurrencesOfString:fileName withString:@""];
        [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:nil];
        [fileManager createFileAtPath:path contents:nil attributes:nil];
    }
    NSFileHandle *handle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
    [handle seekToEndOfFile];
    [handle writeData:data];
    [handle closeFile];
}
@end
