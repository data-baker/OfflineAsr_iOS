//
//  MJLogManager.m
//  MJDamageAssessmentApp
//
//  Created by linxi on 2017/12/27.
//  Copyright © 2017年 linxi. All rights reserved.
//

#import "MJLogManager.h"

@implementation MJLogManager
DEFINE_SINGLETON(MJLogManager)

// 获取当前时间
- (NSDate*)getCurrDate {
    NSDate *date = [NSDate date];
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    NSInteger interval = [zone secondsFromGMTForDate: date];
    NSDate *localeDate = [date dateByAddingTimeInterval: interval];
    return localeDate;
}

#pragma mark - Init

- (instancetype)init{
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
        [timeFormatter setDateFormat:@"yyyy-MM-dd"];
        [timeFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        self.timeFormatter = timeFormatter;
        // 日志的目录路径
        self.basePath = [NSString stringWithFormat:@"%@%@",NSHomeDirectory(),LogFilePath];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL fileExists = [fileManager fileExistsAtPath:self.basePath];
        if (!fileExists) {
            [fileManager createDirectoryAtPath:self.basePath  withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return self;
}

- (NSString*)getLastLog
{
    NSArray *sortedPaths = [self sortAllLogFiles];
    return [[NSString alloc]initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@",self.basePath,[sortedPaths lastObject]] encoding:NSUTF8StringEncoding error:nil];
}

- (NSArray *)getAllLogFullPathOfFile {
    NSArray *files = [self sortAllLogFiles];
    NSMutableArray *fullPathsArray = [NSMutableArray array];
    [files enumerateObjectsUsingBlock:^(NSString *  obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *fullPath = [self.basePath stringByAppendingString:obj];
        [fullPathsArray addObject:fullPath];
    }];
    return fullPathsArray;
}

// MARK: 获取所有的txt文件
- (NSArray *)getAllTxtLogs {
    NSArray *filePaths = [self getAllLogFullPathOfFile];
    NSMutableArray *temps = [NSMutableArray array];
    [filePaths enumerateObjectsUsingBlock:^(NSString *  _Nonnull filePath, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *txt = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
        if (txt.length > 0) {
            [temps addObject:txt];
        }
    }];
    return temps;
    
}

- (NSArray *)sortAllLogFiles {
    NSArray *paths = [[NSFileManager defaultManager] subpathsAtPath:self.basePath];//取得文件列表
    NSArray *sortedPaths = [paths sortedArrayUsingComparator:^(NSString * firstPath, NSString* secondPath) {//
        NSString *firstUrl = [self.basePath stringByAppendingPathComponent:firstPath];
        NSString *secondUrl = [self.basePath stringByAppendingPathComponent:secondPath];
        NSDictionary *firstFileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:firstUrl error:nil];//获取前一个文件信息
        NSDictionary *secondFileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:secondUrl error:nil];//获取后一个文件信息
        id firstData = [firstFileInfo objectForKey:NSFileModificationDate];//获取前一个文件修改时间
        id secondData = [secondFileInfo objectForKey:NSFileModificationDate];//获取后一个文件修改时间
        return [firstData compare:secondData];//升序
    }];
    return sortedPaths;
}


- (void)redirectNSLogToDocumentFolder
{
    [self clearExpiredLog];
    //如果已经连接Xcode调试则不输出到文件
//    if(isatty(STDOUT_FILENO)) {
//        return;
//    }
//    UIDevice *device = [UIDevice currentDevice];
//    //在模拟器不保存到文件中
//    if([[device model] hasSuffix:@"Simulator"]){
//        return;
//    }
    NSString* fileName = [self.timeFormatter stringFromDate:[self getCurrDate]];
    NSString* filePath = [NSString stringWithFormat:@"%@%@.log",self.basePath,fileName];
    self.filePath = filePath;
}


- (void)saveLogFileWithLogInfo:(NSString *)logInfo {
    // 设置日志路径
    if (!self.filePath) {
        NSString* fileName = [self.timeFormatter stringFromDate:[self getCurrDate]];
        NSString* filePath = [NSString stringWithFormat:@"%@%@.log",self.basePath,fileName];
        self.filePath = filePath;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:_filePath]) {
        [fileManager createFileAtPath:_filePath contents:[@">>>>>>>程序运行日志<<<<<<<<\n" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    }
    
    NSFileHandle *handle = [NSFileHandle fileHandleForUpdatingAtPath:_filePath];
    [handle seekToEndOfFile];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"]];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *dateStr = [formatter stringFromDate:[NSDate date]];
    NSString *info = [NSString stringWithFormat:@"\r\n%@:%@",dateStr,logInfo];
    [handle writeData:[info dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
}

void UncaughtExceptionHandler(NSException* exception)
{
    NSString* name = [exception name];
    NSString* reason = [exception reason];
    NSArray* symbols = [exception callStackSymbols];
    //异常发生时的调用栈
    NSMutableString* strSymbols = [[NSMutableString alloc]init];
    //将调用栈拼成输出日志的字符串
    for (NSString* item in symbols)
    {
        [strSymbols appendString: item];
        [strSymbols appendString: @"\r\n"];
    }

    //将crash日志保存到Document目录下的Log文件夹下
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *logDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Log"];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:logDirectory]) {
        [fileManager createDirectoryAtPath:logDirectory  withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *logFilePath = [logDirectory stringByAppendingPathComponent:@"UncaughtException.log"];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"]];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *dateStr = [formatter stringFromDate:[NSDate date]];

    NSString *crashString = [NSString stringWithFormat:@"<- %@ ->[ Uncaught Exception ]\r\nName: %@, Reason: %@\r\n[ Fe Symbols Start ]\r\n%@[ Fe Symbols End ]\r\n\r\n", dateStr, name, reason, strSymbols];
    //把错误日志写到文件中
    if (![fileManager fileExistsAtPath:logFilePath]) {
        [crashString writeToFile:logFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }else{
        NSFileHandle *outFile = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
        [outFile seekToEndOfFile];
        [outFile writeData:[crashString dataUsingEncoding:NSUTF8StringEncoding]];
        [outFile closeFile];
    }

    //把错误日志发送到邮箱
    /*
     NSString *urlStr = [NSString stringWithFormat:@"mailto://xingyang.yuan@dataenlighten.com?subject=bug报告-%@&body=感谢您的配合!<br><br><br>错误详情:<br>%@",MyUserId,crashString];
     NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
     [[UIApplication sharedApplication] openURL:url];
     */
}

/**
 *  清空过期的日志
 */
- (void)clearExpiredLog {
    // 获取日志目录下的所有文件
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.basePath error:nil];
    for (NSString* file in files) { // String   message.length
        if (file.length < 4) { // suffix -> .log ;  pretect code
            return;
        }
        NSString *dateString = [file substringWithRange:NSMakeRange(0, file.length - 4)];
        NSDate* date = [self.timeFormatter dateFromString:dateString];
        if (date) {
            NSTimeInterval oldTime = [date timeIntervalSince1970];
            NSTimeInterval currTime = [[self getCurrDate] timeIntervalSince1970];
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


@end
