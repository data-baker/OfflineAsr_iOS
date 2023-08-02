//
//  DBLogManager.m
//  DBCommon
//
//  Created by 李明辉 on 2020/9/8.
//  Copyright © 2020 biaobei. All rights reserved.
//

#import "DBLogManager.h"
#import "DBCommonConst.h"
#import "DBOfflineAsrUtil.h"

static const int LogMaxSaveDay = 15;
static const NSString *LogFilePath = @"/Documents/DBLog/";

@interface DBLogManager ()
@property(nonatomic,strong)NSDateFormatter * dateFormatter;
@property(nonatomic,strong)NSDateFormatter * timeFormatter;
@property(nonatomic,copy)NSString * basePath;
@end

@implementation DBLogManager

+ (instancetype)sharedInstance {
    static DBLogManager * instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!instance) {
            instance = [[DBLogManager alloc]init];
        }
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 创建日期格式化
        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc]init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
        // 设置时区，解决8小时
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        self.dateFormatter = dateFormatter;
        
        // 创建时间格式化
        NSDateFormatter* timeFormatter = [[NSDateFormatter alloc]init];
        [timeFormatter setDateFormat:@"HH:mm:ss"];
        [timeFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        self.timeFormatter = timeFormatter;
     
        // 日志的目录路径
        self.basePath = [NSString stringWithFormat:@"%@%@",NSHomeDirectory(),LogFilePath];
        // 清除掉历史的数据
        [self clearExpiredLog];
    }
    return self;
}

+ (void)logWithMessage:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2)  {
    // 1. 首先创建多参数列表
    va_list args;
    // 2. 开始初始化参数, start会从format中 依次提取参数, 类似于类结构体中的偏移量 offset 的 方式
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    // 3. end 必须添加, 具体可参考
    va_end(args);
    dispatch_queue_t log_queue = dispatch_queue_create("com.biaobei.log", DISPATCH_QUEUE_SERIAL);
    dispatch_async(log_queue, ^{
        if (KAsrUtil.log) {
            NSString *  fMsg = [msg stringByAppendingString:@"\n"];
            [KDBLogerManager saveCriticalSDKRunData:fMsg];
            NSLog(@"%@",fMsg);

        }
    });
}

- (void)saveCriticalSDKRunData:(NSString *)stringData {
    // 获取当前日期做为文件名
    NSData *writeData = [stringData dataUsingEncoding:NSUTF8StringEncoding];
    NSString* fileName = [self.dateFormatter stringFromDate:[NSDate date]];
    NSString* filePath = [NSString stringWithFormat:@"%@%@",self.basePath,fileName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL createPathOk = YES;
    NSString *directPath = [filePath stringByDeletingLastPathComponent];
    if(![fileManager fileExistsAtPath:directPath isDirectory:&createPathOk]) {
        [fileManager createDirectoryAtPath:directPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if(![fileManager fileExistsAtPath:filePath]) {
        [stringData writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }else {
        NSFileHandle* fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
        [fileHandler seekToEndOfFile];
        [fileHandler writeData:writeData];
        [fileHandler closeFile];
    }
}

- (void)clearExpiredLog {
    // 获取日志目录下的所有文件
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.basePath error:nil];
    for (NSString* file in files) {
        NSDate* date = [self.dateFormatter dateFromString:file];
        if (date) {
            NSTimeInterval oldTime = [date timeIntervalSince1970];
            NSTimeInterval currTime = [[DBLogManager getCurrDate] timeIntervalSince1970];
            NSTimeInterval second = currTime - oldTime;
            int day = (int)second / (24 * 3600);
            if (day >= LogMaxSaveDay) {
                // 删除该文件
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@",self.basePath,file] error:nil];
                NSLog(@"[%@]日志文件已被删除！",file);
            }
        }
    }
    
}
// 获取当前时间
+ (NSDate*)getCurrDate{
    NSDate *date = [NSDate date];
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    NSInteger interval = [zone secondsFromGMTForDate: date];
    NSDate *localeDate = [date dateByAddingTimeInterval: interval];
    return localeDate;
}


@end
