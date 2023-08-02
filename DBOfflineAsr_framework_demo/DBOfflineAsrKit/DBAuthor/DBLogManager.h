//
//  DBLogManager.h
//  DBCommon
//
//  Created by 李明辉 on 2020/9/8.
//  Copyright © 2020 biaobei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef db_dispatch_main_async_safe
#define db_dispatch_main_async_safe(block)\
    if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(dispatch_get_main_queue())) {\
        block();\
    } else {\
        dispatch_async(dispatch_get_main_queue(), block);\
    }
#endif

#define TagDebug @"[Debug]:"
#define TagInfo @"[Info]:"
#define TagError @"[Error]:"

#define DBLog(fmt,...) [DBLogManager logWithMessage:@"%s:%d" fmt, __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__]

#define KDBLogerManager [DBLogManager sharedInstance]

@interface DBLogManager : NSObject

+ (instancetype)sharedInstance;
//  保存用户的log信息
+ (void)logWithMessage:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
@end

NS_ASSUME_NONNULL_END
