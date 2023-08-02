//
//  DBRecognitionResult.h
//  SherpaNcnn
//
//  Created by 林喜 on 2023/4/26.
//

#import <Foundation/Foundation.h>
#import "c-api.h"

NS_ASSUME_NONNULL_BEGIN

@interface DBRecognitionResult : NSObject
{
    @public
    SherpaNcnnResult * _result;

}

@property(nonatomic,copy)NSString * text;

- (void)setResult:(SherpaNcnnResult *)result;

@end

NS_ASSUME_NONNULL_END
