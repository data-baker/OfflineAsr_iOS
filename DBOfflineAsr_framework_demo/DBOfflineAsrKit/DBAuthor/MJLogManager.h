//
//  MJLogManager.h
//  MJDamageAssessmentApp
//
//  Created by linxi on 2017/12/27.
//  Copyright © 2017年 linxi. All rights reserved.
//

#import <Foundation/Foundation.h>

//声明单例
#undef    DECLARE_SINGLETON
#define DECLARE_SINGLETON( __class ) \
- (__class *)sharedInstance; \
+ (__class *)sharedInstance;

//定义单例
#undef    DEFINE_SINGLETON
#define DEFINE_SINGLETON( __class ) \
- (__class *)sharedInstance \
{ \
return [__class sharedInstance]; \
} \
+ (__class *)sharedInstance \
{ \
static dispatch_once_t once; \
static __class * __singleton__; \
dispatch_once( &once, ^{ __singleton__ = [[[self class] alloc] init]; } ); \
return __singleton__; \
}


// 日志保留最大天数
static const int LogMaxSaveDay = 30;
// 日志文件保存目录
static const NSString* LogFilePath = @"/Documents/MJLog/";

@interface MJLogManager : NSObject
DECLARE_SINGLETON(MJLogManager)


// 日期格式化
@property (nonatomic,retain) NSDateFormatter* dateFormatter;
// 时间格式化
@property (nonatomic,retain) NSDateFormatter* timeFormatter;

@property(nonatomic,strong)NSString * filePath;

// 日志的目录路径
@property (nonatomic,copy) NSString* basePath;

- (void)redirectNSLogToDocumentFolder;

- (NSString*)getLastLog;

/// 将日志保存到本地
/// @param logInfo 日志信息
- (void)saveLogFileWithLogInfo:(NSString *)logInfo;

/// 获取所有的本地日志
- (NSArray *)getAllTxtLogs;

@end
