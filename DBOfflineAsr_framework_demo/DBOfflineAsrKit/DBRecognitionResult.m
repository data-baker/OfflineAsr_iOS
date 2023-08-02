//
//  DBRecognitionResult.m
//  SherpaNcnn
//
//  Created by 林喜 on 2023/4/26.
//

#import "DBRecognitionResult.h"

@implementation DBRecognitionResult

- (NSString *)text {
    NSString *text = [NSString stringWithCString:_result->text encoding:NSUTF8StringEncoding];
    return text;
}
- (void)dealloc {
    DestroyResult(_result);
}

- (void)setResult:(SherpaNcnnResult *)result {
    _result = result;
}

@end
