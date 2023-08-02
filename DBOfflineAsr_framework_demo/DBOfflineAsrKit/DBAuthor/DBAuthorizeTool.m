//
//  DBAuthorizeTool.m
//  WebSocketDemo
//
//  Created by linxi on 2020/4/20.
//  Copyright © 2020 newbike. All rights reserved.
//

#import "DBAuthorizeTool.h"
#import "DBCKeyChainStore.h"
#import "DBASRNetworkHelper.h"
#import "DBVRReachability.h"
#import <sys/utsname.h>//要导入头文件
#import <CommonCrypto/CommonDigest.h>
#import "DBOfflineAsrUtil.h"
#import "DBLogManager.h"

static NSString *encryptionKey = @"nha735n197nxn";
/// 设备ID,设备的唯一标识
NSString *const DBUid = @"DBOfflineVCUid";
/// 设备的激活时间
NSString *const DBDateActivation = @"dateActivation";
/// 设备信息
NSString *const DBDeviceInfo = @"deviceInfo";

@implementation DBAuthorizeTool

+ (BOOL)isNetwork {
    // 没有网络，并且有激活信息则可以使用
    if ([[DBVRReachability reachabilityForInternetConnection] currentReachabilityStatus] == NotReachable) {
        return NO;
    }else {
        return YES;
    }
}

+ (BOOL)canUseOfflineSynthesisWithUserId:(NSString *)userId {
    NSInteger activationDays = [self numberOfDayActivationWithUserId:userId];
    if (activationDays > 7 || activationDays < 0) {
        return NO;
    }else {
        return YES;
    }
}


/*
字段    描述
deviceModel    设备机型
systemVersion    iOS 系统号
SDKVersion    SDK的版本号
SDKBuildVersion    SDK构建版本号
SDKPakegeName    SDK包名
deviceId    设备的唯一标识，只生成一次，保存在手机中，绑定有BundleId；
 */

+ (NSDictionary *)getDeveiceInfoDictionaryWithScope:(NSString *)scope {
    if(scope.length == 0) {
        scope = @"asr-offline";
    }
    NSString *deviceModel = [DBAuthorizeTool getCurrentDeviceModel];
    NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
    NSString *SDKVersion = [DBAuthorizeTool sdkVersion];
    NSString *SDKBuildVersion = [DBAuthorizeTool sdkBuildVersion];
    NSString *SDKPakegeName = [DBAuthorizeTool SDKPakegeName];
    NSDictionary *dict = @{@"mobileModel":deviceModel,
                           @"systemSdk":systemVersion,
                           @"sdkVersion":SDKVersion,
                           @"buildNumber":SDKBuildVersion,
                           @"sdkPackage":SDKPakegeName,
                           @"scope":scope
                           
    };
    return dict;
}
+ (BOOL)isVaildAuthorWithUserId:(NSString *)userId {
    NSString *deviceInfo = [self getLocalDeviceInfoWithUserId:userId];
    NSString *currentDeviceInfo = [self getCurrentDeviceModel];
    NSString *currentMd5DeviceInfo = [self md5EncryptWithString:currentDeviceInfo];
    if (deviceInfo && deviceInfo.length > 0 && [currentMd5DeviceInfo isEqualToString:deviceInfo]) {
        DBLog(@"%@%@",TagDebug,@"isValid");
        return YES;
    }
    DBLog(@"%@获取授权无效:currentDeviceInfo %@,md5 equal %@",TagError,currentDeviceInfo,@([currentMd5DeviceInfo isEqualToString:deviceInfo]));
    return NO;
}

+ (NSInteger)numberOfDayActivationWithUserId:(NSString *)userId {
    NSDateFormatter *outputFormatter = [self getcurrentDateformatter];
    NSDictionary *dict = [self getUserInfoByUserId:userId];
    NSString *lastDateString = dict[DBDateActivation];
    NSDate *lastDate = [outputFormatter dateFromString:lastDateString];
    if (!lastDateString) {
        return -1;
    }
    NSDate *currentDate = [NSDate date];
    NSString *currentFormateString = [outputFormatter stringFromDate:currentDate];
    NSDate *currentFormateDate = [outputFormatter dateFromString:currentFormateString];
    long day = [self compareOneDay:lastDate withAnotherDay:currentFormateDate];
    return day;
}

+ (NSString *)dateStringWithDate:(NSDate *)currentDate {
    NSDateFormatter *outputFormatter = [self getcurrentDateformatter];
    NSString *currentDateString =[outputFormatter stringFromDate:currentDate];
    return currentDateString;
}

+ (void)activeDevicesRequestWithHeaderParams:(NSDictionary *)headerParams messageHander:(DBMessagHandler)messageHandler {
    NSAssert(messageHandler, @"请设置信息的回调");
    // 添加公共信息
    NSDictionary *req = [self getDeveiceInfoDictionary];
    DBLog(@"%@headerParams:%@,req:%@",TagInfo,headerParams,req);
    [[DBASRNetworkHelper shareInstance] postWithUrlString:DBOfflineAuthUrl headerDict:headerParams parameters:req success:^(NSDictionary * _Nonnull data) {
        DBLog(@"%@%@",TagDebug,data);
        if ([data[@"data"] isEqual:[NSNull null]]) {
            messageHandler(-1,@"reuest Data is Null");
            return;
        }
        // status: 0:激活成功，1:该UID在规定时间里已激活 2:该UID的安装量已用尽
        NSInteger status = [data[@"data"][@"status"] integerValue];
        if (status == 0 || status == 1) {
            // 激活成功
            NSString *uid = headerParams[@"uid"];
            NSString *userId = headerParams[@"userId"];
            NSString *deviceMode = [DBAuthorizeTool getCurrentDeviceModel];
            NSString *deviceMd5 = [DBAuthorizeTool md5EncryptWithString:deviceMode];
            NSDictionary *userDict = @{
                DBUid:uid,
                DBDateActivation:[self dateStringWithDate:[NSDate date]],
                DBDeviceInfo:deviceMd5
            };
            // 转化成NSData存在钥匙串
            NSData *userData = [DBAuthorizeTool dataWithDictionary:userDict];
            [[DBCKeyChainStore keyChainStore] setData:userData forKey:[self storeUserOfUserId:userId]];
            messageHandler(0,@"success");
            
        }else if (status == DBDeviceActivityStateInsufficient) {
            messageHandler(214002,@"设备数不足");
        }else if(status == DBDeviceActivityStateTooMuch) {
            messageHandler(214003,@"设备数注册太多");
        }else if (status == DBDeviceActivityStateNetworkFailed) {
            messageHandler(214400,@"网络请求失败");
        }else {
            messageHandler(214401,@"未知授权状态");
        }
    } failure:^(NSError * _Nonnull error) {
        DBLog(@"%@%@",TagInfo,error.description);
        messageHandler(NO,error.description);
    }];
}

-(NSInteger)getDaysFrom:(NSDate *)serverDate To:(NSDate *)endDate
{
    NSCalendar *gregorian = [[NSCalendar alloc]
                             initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    [gregorian setFirstWeekday:2];
    NSDate *fromDate;
    NSDate *toDate;
    [gregorian rangeOfUnit:NSCalendarUnitDay startDate:&fromDate interval:NULL forDate:serverDate];
    [gregorian rangeOfUnit:NSCalendarUnitDay startDate:&toDate interval:NULL forDate:endDate];
    NSDateComponents *dayComponents = [gregorian components:NSCalendarUnitDay fromDate:fromDate toDate:toDate options:0];
    return dayComponents.day;
}

+ (NSDateFormatter *)getcurrentDateformatter {
    NSDateFormatter *outputFormatter = [[NSDateFormatter alloc] init];
    [outputFormatter setLocale:[NSLocale currentLocale]];
    [outputFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"Asia/Shanghai"]];
    [outputFormatter setDateFormat:@"yyyy-MM-dd hh:mm:ss"];
    return outputFormatter;
}

+ (long)compareOneDay:(NSDate*)oneDay withAnotherDay:(NSDate*)anotherDay
{
    NSTimeInterval oneDayIntelVal = [oneDay timeIntervalSinceReferenceDate];
    NSTimeInterval anotherDayInteval = [anotherDay timeIntervalSinceReferenceDate];
    NSTimeInterval timeInteval = anotherDayInteval - oneDayIntelVal;
    long day =   timeInteval / (60*60*24);
    return day;
}

// MARK: Public Method -
// Get UDID
+ (NSString *)getLocalDeviceIdWithUserId:(NSString *)userId {
    NSDictionary *dict = [self getUserInfoByUserId:userId];
    NSString *udidString = dict[DBUid];
    return udidString;
}

// Get Device infomation
+ (NSString *)getLocalDeviceInfoWithUserId:(NSString *)userId {
    NSDictionary *dict = [self getUserInfoByUserId:userId];
    NSString *deviceInfo = dict[DBDeviceInfo];
    return deviceInfo;
}

+ (NSDictionary *)getUserInfoByUserId:(NSString *)userId {
    NSData *data = [[DBCKeyChainStore keyChainStore] dataForKey:[self storeUserOfUserId:userId]];
    NSDictionary *dict = [self dictionaryWithData:data];
    return dict;
}

+ (NSString *)storeUserOfUserId:(NSString *)userId {
    NSString *storeUser = [NSString stringWithFormat:@"asr_%@",userId];
    return storeUser;
}
/// Gernerate UDID, use while loop delet char "-"
+ (NSString *)generateUUIDStringWithUserId:(NSString *)userId {
    NSString *udidString = [self getLocalDeviceIdWithUserId:userId];
    if (!udidString) {
        CFUUIDRef puuid = CFUUIDCreate(nil);
        CFStringRef uuidString = CFUUIDCreateString(nil, puuid);
        NSString *result = (NSString *)CFBridgingRelease(CFStringCreateCopy(NULL, uuidString));
        NSMutableString *tmpResult = result.mutableCopy;
        NSRange range = [tmpResult rangeOfString:@"-"];
        while (range.location != NSNotFound) {
            [tmpResult deleteCharactersInRange:range];
            range = [tmpResult rangeOfString:@"-"];
        }
        udidString = tmpResult;
    }
    return udidString;
}
/// 清除设备的唯一标识
+ (BOOL)clearKeyChainUids {
    BOOL ret = [[DBCKeyChainStore keyChainStore] removeAllItems];
    DBLog(@"%@%@",TagInfo,@(ret));
    return ret;
}

/// 数据转化成字典
/// @param data 数据
+(NSDictionary*)dictionaryWithData:(NSData*)data {
    NSString *receiveStr = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    NSData * datas = [receiveStr dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:datas options:NSJSONReadingMutableLeaves error:nil];
    return jsonDict;
}


/// 字典转化成Data
/// @param dict 字典
+(NSData*)dataWithDictionary:(NSDictionary*)dict
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    return data;
}

/*
字段    描述
deviceModel    设备机型
systemVersion    iOS 系统号
SDKVersion    SDK的版本号
SDKBuildVersion    SDK构建版本号
SDKPakegeName    SDK包名
deviceId    设备的唯一标识，只生成一次，保存在手机中
 */

+ (NSDictionary *)getDeveiceInfoDictionary {
    NSString *deviceModel = [DBAuthorizeTool getCurrentDeviceModel];
    NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
    NSString *SDKVersion = [DBAuthorizeTool sdkVersion];
    NSString *SDKBuildVersion = [DBAuthorizeTool sdkBuildVersion];
    NSString *SDKPakegeName = [DBAuthorizeTool SDKPakegeName];
    NSDictionary *dict = @{@"mobileModel":deviceModel,
                           @"systemSdk":systemVersion,
                           @"sdkVersion":SDKVersion,
                           @"buildNumber":SDKBuildVersion,
                           @"sdkPackage":SDKPakegeName,
                           @"scope":@"asr-offline"
                           
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:0];
    NSString *dataStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    DBLog(@"%@%@",TagInfo,dataStr);
    return dict;
}

+ (NSString *)sdkVersion {
    return KOfflineASRVersion;
}

+ (NSString *)sdkBuildVersion {
    NSString *buildVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    return buildVersion;
}

+ (NSString *)SDKPakegeName {
    // 获取客户SDK的安装包的名称
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return bundleID;
//    return @"com.biaobei.offlineASRSDK.iOS";
}

+(NSString*)getBundleID
{
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
}


+ (NSString *)getCurrentDeviceModel {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSASCIIStringEncoding];
    return deviceModel;
}

// MD5 加密相关

+ (NSString *)md5EncryptWithString:(NSString *)string{
    return [self md5:[NSString stringWithFormat:@"%@%@", encryptionKey, string]];
}

+ (NSString *)md5:(NSString *)string {
    const char *cStr = [string UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02X", digest[i]];
    }
    return result;
}

// test method
/*
 NSArray *allKeys =  [DBCKeyChainStore keyChainStore].allKeys;
 NSLog(@"allKeys:%@",allKeys);
 NSString *bundleId = [self getBundleID];
 NSLog(@"bundleID:%@",bundleId);
 */
@end
