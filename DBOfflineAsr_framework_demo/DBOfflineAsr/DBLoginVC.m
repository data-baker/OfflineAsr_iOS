//
//  DBLoginVC.m
//  DBVoiceEngraverDemo
//
//  Created by linxi on 2020/3/12.
//  Copyright © 2020 biaobei. All rights reserved.
//

#import "DBLoginVC.h"
#import "XCHudHelper.h"
#import "DBOfflineAsr-Swift.h"
#import "DBUserInfoManager.h"
#import "DBOfflineAsrKit.h"
#import "UIView+Toast.h"


#warning  请联系标贝科技获取clientId 和clientSecret, 注意不同的服务使用不同的授权clientId和clientSecret

//product
static NSString *KClientId = @"XXX";
static NSString *KClientSecret = @"XXX";
#define KUserDefalut [NSUserDefaults standardUserDefaults]

@interface DBLoginVC ()
{
    NSString *keyName_;
}
@property (weak, nonatomic) IBOutlet UITextField *clientIdTextField;
@property (weak, nonatomic) IBOutlet UITextField *clientSecretTextField;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@end

@implementation DBLoginVC 

- (void)viewDidLoad {
    [super viewDidLoad];
    self.titleLabel.text = self.sdkName;
    self.subtitleLabel.text = @"请输入授权信息";
    [self restoreUserInfo];
}

- (void)restoreUserInfo {
    NSDictionary *dict = @{
        @"一句话识别":@"oneShot",
        @"实时长语音识别":@"longSpeech",
        @"在线语音合成":@"onlineTTS",
        @"声音转换":@"voiceConvert",
        @"声音复刻":@"voiceReprint",
        @"离线变声":@"offlieVC",
        @"声纹服务":@"voiceprint",
        @"离线Asr":@"offlineAsr"
    };
    NSString *key = dict[_sdkName];
    NSAssert(key, @"key can't be nil");
    keyName_ = key;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSDictionary *authInfo  = [ud objectForKey:key];
    NSString *clientId = authInfo[@"clientId"];
    NSString *clientSecret = authInfo[@"clientSecret"];
    if (clientId.length > 0 && clientSecret.length > 0) {
        self.clientIdTextField.text = clientId;
        self.clientSecretTextField.text = clientSecret;
    }else {
        self.clientIdTextField.text = KClientId;
        self.clientSecretTextField.text = KClientSecret;
        [ud removeObjectForKey:key];
    }
}

- (IBAction)loginAction:(id)sender {
    
    if (self.clientIdTextField.text.length <= 0) {
        
        //        [self.view makeToast:@"请输入clentId" duration:2 position:CSToastPositionCenter];
        return ;
    }
    if (self.clientSecretTextField.text.length <= 0 ) {
        //        [self.view makeToast:@"请输入clentSecret" duration:2 position:CSToastPositionCenter];
        return ;
    }
    NSString *clientId = [self.clientIdTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *clientSecret = [self.clientSecretTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    [[XCHudHelper sharedInstance] showHudOnView:self.view caption:@"" image:nil acitivity:YES autoHideTime:0];
    [[DBOfflineAsrClient shareInstance] setupRecognizerClientId:clientId clientSecret:clientSecret messageHander:^(NSInteger ret, NSString * _Nullable message) {
        if(ret != 0) {
            [[XCHudHelper sharedInstance] hideHud];
            NSLog(@"获取token失败:%@",message);
            NSString *msg = [NSString stringWithFormat:@"获取token失败:%@",message];
            [self.view makeToast:msg duration:2 position:CSToastPositionCenter];
            [KUserDefalut removeObjectForKey:self->keyName_];
            self.handler(NO);
            return;
        }
        
        [[XCHudHelper sharedInstance] hideHud];
        DBUserInfoManager *infoManager = [DBUserInfoManager shareManager];
        infoManager.clientId = clientId;
        infoManager.clientSecret = clientSecret;
        infoManager.sdkType = self.sdkName;
        NSDictionary *authInfo = @{
            @"clientId":clientId,
            @"clientSecret":clientSecret
        };
        [KUserDefalut setObject:authInfo forKey:self->keyName_];
        [self.view makeToast:@"获取授权成功" duration:2 position:CSToastPositionCenter];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:nil];
            if (self.handler) {
                self.handler(YES);
            }
        });
    }];
    
    
//    [DBAuthentication  setupClientId:clientId clientSecret:clientSecret block:^(NSString * _Nullable token, NSError * _Nullable error) {
//        if (error) {
//            [[XCHudHelper sharedInstance] hideHud];
//            NSLog(@"获取token失败:%@",error);
//            NSString *msg = [NSString stringWithFormat:@"获取token失败:%@",error.description];
//            [self.view makeToast:msg duration:2 position:CSToastPositionCenter];
//            self.handler(NO);
//            return;
//        }
//        [[XCHudHelper sharedInstance] hideHud];
//        DBUserInfoManager *infoManager = [DBUserInfoManager shareManager];
//
//        infoManager.clientId = clientId;
//        infoManager.clientSecret = clientSecret;
//        infoManager.sdkType = self.sdkName;
//        NSDictionary *authInfo = @{
//            @"clientId":clientId,
//            @"clientSecret":clientSecret
//        };
//        [KUserDefalut setObject:authInfo forKey:self->keyName_];
//        [self dismissViewControllerAnimated:YES completion:nil];
//        if (self.handler) {
//            self.handler(YES);
//        }
//        }];
     
}
- (IBAction)comeBack:(UIButton *)sender {
    if (self.handler) {
        self.handler(NO);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (IBAction)clearAuth:(id)sender {
    if(self.clearHandler) {
        self.clientIdTextField.text = @"";
        self.clientSecretTextField.text = @"";
        // 清除内存
        DBUserInfoManager *infoManager = [DBUserInfoManager shareManager];
        infoManager.clientId = @"";
        infoManager.clientSecret = @"";
        infoManager.sdkType = @"";
        [KUserDefalut removeObjectForKey:self->keyName_];
        self.clearHandler(true);
    }
    
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.clientIdTextField resignFirstResponder];
    [self.clientSecretTextField resignFirstResponder];
}
// 增加userDefault 的设置

@end
