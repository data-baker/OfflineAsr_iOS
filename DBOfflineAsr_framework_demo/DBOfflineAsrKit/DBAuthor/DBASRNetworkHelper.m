//
//  DBNetworkHelper.m
//  DBFlowTTS
//
//  Created by linxi on 2019/11/14.
//  Copyright © 2019 biaobei. All rights reserved.
//

#import "DBASRNetworkHelper.h"
#import <CommonCrypto/CommonDigest.h>


@interface DBASRNetworkHelper ()

@property(nonatomic,copy)NSString * clientId;
@property(nonatomic,copy)NSString * clientSecret;
@property(nonatomic,assign)NSInteger  retryCount;
@end

@implementation DBASRNetworkHelper

+ (instancetype)shareInstance {
    static DBASRNetworkHelper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DBASRNetworkHelper alloc]init];
        instance.retryCount = 1;
    });
    return instance;
}

//GET请求
- (void)getWithUrlString:(NSString *)url parameters:(id)parameters success:(DBSuccessBlock)successBlock failure:(DBFailureBlock)failureBlock
{
    NSString * clientId = parameters[@"client_id"];
    NSString * clientSecret = parameters[@"client_secret"];
    if (clientId) {
        self.clientId = clientId;
    }
    if (clientSecret) {
        self.clientSecret = clientSecret;
    }
    
    NSMutableString *mutableUrl = [[NSMutableString alloc] initWithString:url];
    if ([parameters allKeys]) {
        [mutableUrl appendString:@"?"];
        for (id key in parameters) {
            NSString *value = [[parameters objectForKey:key] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            [mutableUrl appendString:[NSString stringWithFormat:@"%@=%@&", key, value]];
        }
    }
    NSString *urlEnCode = [[mutableUrl substringToIndex:mutableUrl.length - 1] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlEnCode]];
    NSURLSession *urlSession = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [urlSession dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        /// 主线程回调结果
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                failureBlock(error);
            } else {
                NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                successBlock(dic);
            }
        });
    }];
    [dataTask resume];
}


- (void)getAudioDataWithUrlString:(NSString *)url parameters:(NSDictionary *)parameters success:(DBSuccessDataBlock)successBlock failure:(DBFailureBlock)failureBlock
{
    NSMutableString *mutableUrl = [[NSMutableString alloc] initWithString:url];
    if ([parameters allKeys]) {
        [mutableUrl appendString:@"?"];
        for (id key in parameters) {
            NSString *value = [parameters objectForKey:key];
            [mutableUrl appendString:[NSString stringWithFormat:@"%@=%@&", key, value]];
        }
    }
    NSString *urlEnCode = [[mutableUrl substringToIndex:mutableUrl.length - 1] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlEnCode]];
    NSURLSession *urlSession = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [urlSession dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        /// 主线程回调结果
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                failureBlock(error);
                return;
            }
            // TODO: 此处如果是Token请求失败，还需要进行token刷新
            if (data.length < 500) { // 请求失败,
                NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                NSInteger errorCode = [dic[@"err_no"] integerValue];
                if (errorCode != 30000){
                    NSLog(@"dic:%@",dic);
                    NSString *errMsg = @"请求发生错误";
                    if (dic[@"err_msg"]) {
                        errMsg = dic[@"err_msg"];
                    }
                    NSError *error = [NSError errorWithDomain:networkErrorDomain code:22190003 userInfo:@{NSLocalizedDescriptionKey: errMsg}];
                    failureBlock(error);
                    return;
                }
                if (self.retryCount > 2) {
                    NSString *errMsg = @"请求发生错误";
                    if (dic[@"err_msg"]) {
                        errMsg = dic[@"err_msg"];
                    }
                    NSError *error = [NSError errorWithDomain:networkErrorDomain code:30000 userInfo:@{NSLocalizedDescriptionKey: errMsg}];
                    self.retryCount = 1;
                    failureBlock(error);
                    return;
                }
                
                // 刷新token
                NSMutableDictionary *parametersToken = [NSMutableDictionary dictionary];
                parametersToken[@"client_id"] = self.clientId;
                parametersToken[@"client_secret"] = self.clientSecret;
                parametersToken[@"grant_type"] = @"client_credentials";
                [self getWithUrlString:getTokenURL parameters:parametersToken success:^(NSDictionary * _Nullable data) {
                    NSString *token = data[@"access_token"];
                    if (!token) {
                        NSError *error = [NSError errorWithDomain:networkErrorDomain code:30000 userInfo:@{NSLocalizedDescriptionKey: @"token失效,刷新token失败"}];
                        self.retryCount = 1;
                        failureBlock(error);
                        return;
                    }
                    self.retryCount++;
                    NSMutableDictionary *mutableParams = [NSMutableDictionary dictionaryWithDictionary:parameters];
                    if (self.delegate && [self.delegate respondsToSelector:@selector(updateToken:)]) {
                        [self.delegate updateToken:token];
                    }
                    mutableParams[@"access_token"] = token;
                    NSLog(@"parameters :%@",parameters);
                    [self getAudioDataWithUrlString:url parameters:mutableParams success:successBlock failure:failureBlock];
                } failure:^(NSError * _Nullable error) {
                    self.retryCount++;
                    NSLog(@"error");
                    if (self.retryCount > 2) {
                        failureBlock(error);
                        self.retryCount = 1;
                    }
                }];
                return;
            }
            successBlock(data);
        });
        
    }];
    [dataTask resume];
}

//POST请求 使用NSMutableURLRequest可以加入请求头
- (void)postWithUrlString:(NSString *)url headerDict:(NSDictionary *)headerParameters parameters:(id)parameters success:(DBSuccessBlock)successBlock failure:(DBFailureBlock)failureBlock
{
    NSURL *nsurl = [NSURL URLWithString:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsurl];    
    //设置请求类型
    request.HTTPMethod = @"POST";
    
    // 固定参数
    [request setValue:@"v1" forHTTPHeaderField:@"version"];// 版本号
    [request setValue:@"application/json;charset=utf-8" forHTTPHeaderField:@"Content-Type"];

    // 通过header返回的参数
    for (NSString *key in headerParameters) {
        [request setValue:headerParameters[key] forHTTPHeaderField:key];
    }
    
    // 签名相关
    NSMutableDictionary * headerDic = [[NSMutableDictionary alloc]init];
    NSString * unixTime = [self getUnixTime];
    NSString * nounce = [self getNounce];
    headerDic[@"nounce"] =  nounce;
    headerDic[@"timestamp"] =  unixTime;
    headerDic[@"userId"] = headerParameters[@"userId"];
    headerDic[@"token"] = headerParameters[@"token"];
    [request setValue:unixTime forHTTPHeaderField:@"timestamp"];//10位的UNIX时间戳
    [request setValue:nounce forHTTPHeaderField:@"nounce"];// 6位的随机数
    [request setValue:[self getSignature:headerDic] forHTTPHeaderField:@"signature"];//版本
    //把参数放到请求体内
    NSString *postStr = [DBASRNetworkHelper parseParams:parameters];
    request.HTTPBody = [postStr dataUsingEncoding:NSUTF8StringEncoding];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { //请求失败
                failureBlock(error);
            } else {  //请求成功
                NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                successBlock(dic);
            }
        });
    }];
    [dataTask resume];  //开始请求
}

//重新封装参数 加入app相关信息
+ (NSString *)parseParams:(NSDictionary *)params
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:params];
    
    NSDate *date = [NSDate date];
    NSTimeInterval timeinterval = [date timeIntervalSince1970];
    [parameters setObject:[NSString stringWithFormat:@"%.0lf",timeinterval] forKey:@"auth_timestamp"];//请求时间戳
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:&parseError];
    if (parseError) {
        NSLog(@"parseError:%@",parseError);
    }
    NSString *result =  [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return result;
}

// MARK: Private Methods
- (NSString *)getNounce {
    int a = arc4random() % 100000;
    NSString *str = [NSString stringWithFormat:@"%06d", a];
    return str;
}

- (NSString *)getUnixTime {
    
    NSTimeInterval time=[[NSDate date] timeIntervalSince1970];
    long long int currentTime = (long long int)time;
    NSString *unixTime = [NSString stringWithFormat:@"%llu", currentTime];
    return unixTime;
    
}

- (NSString *)getSignature:(NSMutableDictionary*) params{
    
    NSArray *keyArray = [params allKeys];
    NSArray *sortArray = [keyArray sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2 options:NSNumericSearch];
    }];
    NSMutableArray *valueArray = [NSMutableArray array];
    for (NSString *sortString in sortArray) {
        [valueArray addObject:[params objectForKey:sortString]];
    }
    NSMutableArray *signArray = [NSMutableArray array];
    for (int i = 0; i < sortArray.count; i++) {
        NSString *keyValueStr = [NSString stringWithFormat:@"%@=%@",sortArray[i],valueArray[i]];
        [signArray addObject:keyValueStr];
    }
    NSString *sign = [signArray componentsJoinedByString:@"&"];
    sign = [NSString stringWithFormat:@"%@&v1",sign];
    sign = [self MD5ForLower32Bate:sign];
    if ([self isBlank:sign]) {
        NSString *occurrencesString = @"s";
        NSRange range = [sign rangeOfString:occurrencesString];
        sign = [sign stringByReplacingCharactersInRange:range withString:@"b"];
    }
    sign = [NSString stringWithFormat:@"%@%@",sign,params[@"nounce"]];
    sign = [self MD5ForLower32Bate:sign];
    return sign;
}
- (BOOL)isBlank:(NSString *)str{
    NSRange _range = [str rangeOfString:@"s"];
    if (_range.location != NSNotFound) {
        return YES;
    }else {
        return NO;
    }
}

-(NSString *)MD5ForLower32Bate:(NSString *)str{
    
    //要进行UTF8的转码
    const char* input = [str UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(input, (CC_LONG)strlen(input), result);
    
    NSMutableString *digest = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (NSInteger i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [digest appendFormat:@"%02x", result[i]];
    }
    
    return digest;
}


@end
