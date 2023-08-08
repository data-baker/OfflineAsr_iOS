# 标贝离线ASR接入文档（iOS)

### 适用场景特点

离线SDK适用于有以下特点的场景：

* 特殊网络环境：无网、弱网、局域网等情况，无法连接公网的环境下。
* 数据安全要求高：由于行业特点所带来的的数据敏感性，即使可以连接公网也不可请求。
* 识别速度要求高：由于各地网络线路，机房部署等诸多原因，网络请求速度存在不可控因素。
* 运行稳定要求高：需要尽可能避免网络抖动、机房故障等影响，进一步控制可用性影响因素。

#### 兼容性说明

iOS系统： `iOS 11.0`及以上；

架构⽀持：`arm64`及以上；

Bitcode设置：`Enable Bitcode` 设置为`NO`;

离线设备消耗说明： 一个`bundleId`会认为是一个设备

### 体验地址

获取授权地址：[Demo](https://ai.data-baker.com/#/asr/offline)

### 1. Xcode集成lib（参考demo）

### 依赖说明

#### 	1.1依赖库

| 依赖库                      | 集成方式                                                     | 使用说明            |
| --------------------------- | ------------------------------------------------------------ | ------------------- |
| `DBOfflineAsrKit.framework` | `Target->Build Setting->Search Paths -> Library Search Paths`, 增加`$(inherited)` + 库的相对路径 | 离线`Asr`引擎依赖库 |

#### 	1.2 依赖资源

| 依赖资源                          | 说明                    |
| --------------------------------- | ----------------------- |
| encoder_jit_trace-pnnx.ncnn.param | 模型的编码param文件     |
| encoder_jit_trace-pnnx.ncnn.bin   | 模型的编码bin文件       |
| decoder_jit_trace-pnnx.ncnn.param | 模型的解码param文件     |
| decoder_jit_trace-pnnx.ncnn.bin   | 模型的解码bin文件       |
| joiner_jit_trace-pnnx.ncnn.param  | 模型的joiner的param文件 |
| joiner_jit_trace-pnnx.ncnn.bin    | 模型的joiner的bin文件   |
| tokens.txt                        | 授权的token文件         |

### 2. SDK关键类

1. `DBOfflineAsrClient`：语⾳合成关键业务处理类，全局只需⼀个实例即可,并且 需要注册⾃⼰为该类的回调对象；
2. ` DBAsrDelegate` ： 识别的代理回调；

### 3.调⽤说明

#### 3.1.引⼊SDK的header⽂件

```objc
 #import <DBOfflineAsrKit.h>
```

#### 3.2.设置鉴权

`SDK`的鉴权需要传入clientId和clientSecret, 每个应用视为一个设备；

设置鉴权示例

```swift
 asrClient.setupRecognizerClientId("xxx", clientSecret: "xxx") { ret , messag in
            print("asr author \(ret), message: \(messag ?? "")")
            if ret != 0 {
            }
        }
```

> 说明：
>
> `offClientId`: 离线Asr的ClientId
>
> `offClientSecret`:离线Asr的 ClientSecret
>
> `messageHandler`：回调鉴权的结果， 如果ret == 0，表示鉴权成功，其他的表示鉴权失败,具体的失败信息见请求列表

#### 3.3 设置识别的模型文件

```swift
        let encoderParam = getResource("encoder_jit_trace-pnnx.ncnn", "param")
        let encoderBin = getResource("encoder_jit_trace-pnnx.ncnn", "bin")
        let decoderParam = getResource("decoder_jit_trace-pnnx.ncnn", "param")
        let decoderBin = getResource("decoder_jit_trace-pnnx.ncnn", "bin")
        let joinerParam = getResource("joiner_jit_trace-pnnx.ncnn", "param")
        let joinerBin = getResource("joiner_jit_trace-pnnx.ncnn", "bin")
        let tokens = getResource("tokens", "txt")
    asrClient.setupRecognizer(withEncoderParam: encoderParam, encoderBin: encoderBin, decoderParam: decoderParam, decoderBin: decoderBin, joinerParam: joinerParam, joinerBin: joinerBin, tokens: tokens,numberOfThread: 1)
```

> 1. 此方法加载合成的模型文件，模型文件请联系标贝科技获取，Demo中会内置一份默认的模型文件；
> 2. 设置加载的资源文件到asrClient的识别类中；
> 2. numberOfThread表示默认使用的CPU核，默认为单核，最高支持6核。

### 4.设置回调代理

```swift
asrClient.delegate = self		
```

> 1. 设置回调的代理

实现回调的代理方法,`DBAsrDelegate`

#### DBAsrDelegate 回调类⽅法说明

```swift
extension ViewController: DBAsrDelegate {
  // 1
    func identifyTheCallback(_ message: String!, sentenceEnd: Bool) {
        print("[debug]: message: \(String(describing: message)), sentenceEnd: \(sentenceEnd)")
     }
  // 2
    func onError(_ code: Int, message: String!) {
        print("error code :\(code), message: \(String(describing: message))")
    }
  // 3
  func dbValues(_ db: Int) {
    
  }
}
```

> 具体的回调说明参照下文的 DBAsrDelegate 回调类⽅法说明
>
> 1.  表示代理的回调数据， 其中message表示回调识别到的音频数据， sentenceEnd表示识别的结果是否结束，1表示此次识别结束，0表示当前识别正在进行。
> 2. 表示识别的错误， code表示识别到的错误码， message表示识别到的错误提示信息。
> 3. 音频分贝值回调,db范围0～100。

### 5.开启识别

```swift
asrClient.startAsr()
```

> 开启时Asr识别

### 6.结束识别

```swift
 asrClient.stopAsr()
```

> 结束本次的Asr识别，点击停止，立即停止当前的Asr识别；
>

### 7.文件识别

文件识别的调用流程和语音识别的调用方式相似，不同之处在于开启识别和结束识别的方法调用上，具体如下：

#### 7.1开启文件识别

```objc
- (BOOL)startAsrWithFilePath:(NSString *)filePath;
```

> 参数说明： 返回值 Yes 表示开启Asr文件识别成功， No 表示开启Asr文件识别失败，失败原因见错误回调列表；
>
> 开启文件识别，需要传入待识别的文件路径，传输的文件要求PCM格式， 16K采样率，16位位深，单声道的音频数据。

#### 7.2 结束文件识别

```objc
- (void)stopFileRecognize;
```

> 结束文件识别。

### 8. 错误信息说明

#### 8.1失败时返回的msg格式

| 参数名称 | 类型   | 描述                                                 |
| :------- | :----- | :--------------------------------------------------- |
| code     | int    | 1开头的错误表示SDK的本地错误，2开头表示SDK云端的错误 |
| message  | string | 错误描述                                             |

#### 8.2  错误码

| 错误码 | 错误描述             | 解决方法             |
| ------ | -------------------- | -------------------- |
| 114001 | 引擎错误             | 排查引擎的初始化方法 |
| 114002 | 引擎识别失败         | 根据日志查看原因     |
| 114003 | 没有网络             | 开启网络权限         |
| 114004 | 无效授权             | 检查本地授权是否有效 |
| 214002 | 安装量已消耗完       | 购买新的安装量       |
| 214003 | 同一时段激活次数太多 | 稍后重试             |
| 214400 | 网络请求失败         | 检查网络环境         |
| 214401 | 未知授权状态         | 请检查授权信息       |



### 9.  常见问题

1. 数据的识别结果展示为乱码怎么办？

   > 检查识别的音频格式，要求识别的数据为单声道，16K采样率，16位位深的音频。

