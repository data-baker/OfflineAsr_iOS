//
//  DBOfflineConvertVoiceClient.m
//  DBAudioSDKDemo
//
//  Created by linxi on 2021/10/26.
//

#import "DBOfflineAsrUtil.h"
#import "DBASRNetworkHelper.h"
#import "DBAuthorizeTool.h"
#import <AudioToolbox/AudioToolbox.h>
#import "DBLogManager.h"

#define kAudioFolder @"AudioFolder" // 音频文件夹
static NSString * DBVCClientDomain = @"DBOfflienAsrDomain";

@interface DBOfflineAsrUtil()
@property(nonatomic,copy)NSString  * clientId;
@property(nonatomic,copy)NSString  * clientSecret;
@property(nonatomic,strong)NSString * accessToken;
@end

@implementation DBOfflineAsrUtil

+ (instancetype)shareInstance {
    static DBOfflineAsrUtil *offlineInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        offlineInstance = [[DBOfflineAsrUtil alloc]init];
    });
    return offlineInstance;
}

- (void)setupOfflineAsrSDKClientId:(NSString *)clientId clientSecret:(NSString *)clientSecret messageHander:(DBMessagHandler)messageHandler {
    NSAssert(messageHandler, @"请设置失败回调");
    // no network and have license can synthesis
    if (![DBAuthorizeTool isNetwork] && [DBAuthorizeTool isVaildAuthorWithUserId:self.clientId]) {
        DBLog(@"%@%@",TagInfo,@"No network, authore success");
        messageHandler(0,@"success");
        return;
    }
    self.clientId = clientId;
    self.clientSecret = clientSecret;
    [self refreshTokenIfNeedCompleteHandler:^(NSInteger ret, NSString * _Nonnull message) {
        if (ret != 0) { // 获取失败
            messageHandler(ret,message);
            DBLog(@"%@%@",TagError,message);
            return;
        }
        // 如果是第一次授权，需要先获取授权信息
        NSString *deviceId = [DBAuthorizeTool getLocalDeviceIdWithUserId:self.clientId];
        if (!deviceId  || deviceId.length == 0) {//  第一次授权时，需要进行授权
            [self refreshAuthoreInfoIfNeedWithMessageHandler:messageHandler];
            return;
        }
        // 获取授权信息
        BOOL isValidDeviceInfo = [DBAuthorizeTool isVaildAuthorWithUserId:self.clientId];
        if (!isValidDeviceInfo) { // 授权信息错误，不能进行合成
            DBLog(@"%@%@",TagError,@"Author failed, Clear local auth");
            [DBAuthorizeTool clearKeyChainUids];
            messageHandler(DBOffAuthErrorAuthFailed,@"授权信息无效");
            return;
        }
        BOOL canUse = [DBAuthorizeTool canUseOfflineSynthesisWithUserId:self.clientId];
        if (canUse) { // 有效期内，可以合成
            DBLog(@"%@%@",TagInfo,@"Time is valid");
            messageHandler(0,@"success");
        }else {
            DBLog(@"%@%@",TagInfo,@"Time inVaild, refresh author");
            [self refreshAuthoreInfoIfNeedWithMessageHandler:messageHandler];
        }
    }];
}
- (void)clearAuth {
    [DBAuthorizeTool clearKeyChainUids];
}

- (NSError *)errorWithCode:(NSInteger)code info:(NSString *)info {
    NSError *error = [NSError errorWithDomain:DBVCClientDomain code:code userInfo:@{NSLocalizedDescriptionKey:info}];
    return error;
}

- (void)refreshAuthoreInfoIfNeedWithMessageHandler:(DBMessagHandler)messageHandler {
    NSString *udidString = [DBAuthorizeTool generateUUIDStringWithUserId:self.clientId];
    NSDictionary *headerParams  = @{
        @"uid":udidString,
        @"userId":self.clientId,
        @"token":self.accessToken
    };
    DBLog(@"%@%@",TagInfo,headerParams);
    [DBAuthorizeTool activeDevicesRequestWithHeaderParams:headerParams messageHander:^(NSInteger ret, NSString * _Nonnull message) {
        DBLog(@"%@ret:%@ message:%@",TagInfo,@(ret),message);
        messageHandler(ret,message);
    }];
}

- (void)refreshTokenIfNeedCompleteHandler:(DBMessagHandler)handler {
    NSAssert(handler, @"请设置refreshTokenIfNeedCompleteHandler方法的回调");
    if (!self.clientId) {
        handler(DBOffAuthErrorPara,@"clientId error");
        return ;
    }
    
    if (!self.clientSecret) {
        handler(DBOffAuthErrorPara,@"clienr secret error");
        return ;
    }
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"client_id"] = self.clientId;
    parameters[@"client_secret"] = self.clientSecret;
    parameters[@"grant_type"] = @"client_credentials";
    [[DBASRNetworkHelper shareInstance] getWithUrlString:getTokenURL parameters:parameters success:^(NSDictionary * _Nullable data) {
        NSString *token =  data[@"access_token"];
        if (!token) {
            handler(DBOffAuthErrorAccessToken,@"刷新token失败");
            return;
        }
        self.accessToken = token;
        handler(0,token);
    } failure:^(NSError * _Nullable error) {
        handler(DBOffAuthErrorAccessToken,error.description);
    }];
}
// 记录运行日志
void writeLog(const char * format,...) {
    DBOfflineAsrUtil *util = [DBOfflineAsrUtil shareInstance];
    if(!util.log) {
        return ;
    }
    va_list ptr;
    va_start(ptr, format);
    NSString *format_ = [NSString stringWithCString:format encoding:NSUTF8StringEncoding];
    NSString *msg = [[NSString alloc] initWithFormat:format_ arguments:ptr];
    NSString *dateString = [util stringWithDate:[NSDate date]];
    msg = [NSString stringWithFormat:@"%@:%@",dateString,msg];
    const char *logs = msg.UTF8String;
    va_end(ptr);
    if ([msg hasPrefix:@"[verbose]"]) {
        return;
    };
    char * logPath = filePathWithName("log.txt");
    //  控制日志文件的大小
    NSString *path_oc = [NSString stringWithCString:logPath encoding:NSUTF8StringEncoding];
    NSError *error;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path_oc error:&error];
    unsigned long long length = [fileAttributes fileSize];
    float fM = length/1024.0/1024.0;
    if (fM > 20) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:path_oc] error:&error];
        if (error) {
            NSLog(@"error :%@",error);
            return;
        }
    }
    FILE *fp = fopen(logPath, "ab+");
    fwrite(logs, 1,strlen(logs), fp);
    fclose(fp);
}

char* filePathWithName(const char * fileName) {
    static char buffer[256];
    //HOME is the home directory of your application
    //points to the root of your sandbox
    strcpy(buffer,getenv("HOME"));
    //concatenating the path string returned from HOME
    strcat(buffer,"/Documents/");
    strcat(buffer, fileName);
    return buffer;
}

- (NSString *)stringWithDate:(NSDate *)date {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *dateString = [dateFormatter stringFromDate:date];
    return dateString;
}

@end
