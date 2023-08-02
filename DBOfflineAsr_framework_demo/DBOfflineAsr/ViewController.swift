//
//  ViewController.swift
//
//

import AVFoundation
import UIKit
import DBOfflineAsrKit

typealias MessageHandler = (Bool, String)->Void

class ViewController: UIViewController {
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var recordBtn: UIButton!
    @IBOutlet weak var voiceImageView: UIImageView!
    var pathArray:[String] = []
    var convertFlag = false
    var fileName = ""
    var totalTime = 0.0

    /// It saves the decoded results so far
    var sentences: [String] = [] {
        didSet {
            updateLabel()
        }
    }
    var lastSentence: String = ""
    let maxSentence: Int = 20
    var results: String {
        if sentences.isEmpty && lastSentence.isEmpty {
            return ""
        }
        if sentences.isEmpty {
            return "0: \(lastSentence.lowercased())"
        }
        
        let start = max(sentences.count - maxSentence, 0)
        if lastSentence.isEmpty {
            return sentences.enumerated().map { (index, s) in "\(index): \(s.lowercased())" }[start...]
                .joined(separator: "\n")
        } else {
            return sentences.enumerated().map { (index, s) in "\(index): \(s.lowercased())" }[start...]
                .joined(separator: "\n") + "\n\(sentences.count): \(lastSentence.lowercased())"
        }
    }
    
    let asrClient = DBOfflineAsrClient.shareInstance()
    
    func updateLabel() {
        DispatchQueue.main.async {
            self.resultLabel.text = self.results
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        asrClient.isLog = true
        resultLabel.text = "标贝离线识别 \n\n请点击按钮开始体验"
        recordBtn.setTitle("开始", for: .normal)
        showLognIn()
    }
    
    @IBAction func onRecordBtnClick(_ sender: UIButton) {
        if recordBtn.currentTitle == "开始" {
            startRecorder()
            recordBtn.setTitle("停止", for: .normal)
        } else {
            stopRecorder()
            recordBtn.setTitle("开始", for: .normal)
        }
    }
    
    
    @IBAction func auth(_ sender: UIButton) {
        showLognIn()
        return
       // 此处的授权为固定的授权，需要修改为可变化的授权
        let clientId = DBUserInfoManager().clientId
        let clientSecret = DBUserInfoManager().clientSecret
        asrClient.setupRecognizerClientId(clientId, clientSecret: clientSecret) { ret , messag in
            print("asr author \(ret), message: \(messag ?? "")")
            if ret != 0 {
                self.view.makeToast(messag,position: .center)
                return
            }
            self.view.makeToast("授权成功", position: .center)
        }
        asrClient.delegate = self
        initRecognizer()
    }
    
    @IBAction func clearAuth(_ sender: UIButton) {
        asrClient.clearAuth()
    }
    
    func showLognIn() {
        let loginVC = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "DBLoginVC") as! DBLoginVC
        loginVC.sdkName = "离线Asr"
        loginVC.handler = {ret in
            guard ret == true else {
                print("获取授权失败")
//                self.view.makeToast()
                return
            }
            print("获取授权成功")
//            self.view.makeToast("获取授权成功")
            self.asrClient.delegate = self
            self.initRecognizer()
        }
        loginVC.modalPresentationStyle = .fullScreen
        navigationController?.present(loginVC, animated: true)
    }
    
    func initRecognizer() {
        let encoderParam = getResource("encoder_jit_trace-pnnx.ncnn.int8", "param")
        let encoderBin = getResource("encoder_jit_trace-pnnx.ncnn.int8", "bin")
        let decoderParam = getResource("decoder_jit_trace-pnnx.ncnn", "param")
        let decoderBin = getResource("decoder_jit_trace-pnnx.ncnn", "bin")
        let joinerParam = getResource("joiner_jit_trace-pnnx.ncnn.int8", "param")
        let joinerBin = getResource("joiner_jit_trace-pnnx.ncnn.int8", "bin")
        let tokens = getResource("tokens", "txt")
        asrClient.setupRecognizer(withEncoderParam: encoderParam, encoderBin: encoderBin, decoderParam: decoderParam, decoderBin: decoderBin, joinerParam: joinerParam, joinerBin: joinerBin, tokens: tokens,numberOfThread: 2)
    }
    
    func startRecorder() {
        voiceImageView.isHidden = false
        lastSentence = ""
        sentences = []
        DBTimeUtil.start();
        if asrClient.startAsr() == false {
            voiceImageView.isHidden = true
            recordBtn.setTitle("开始", for: .normal)
        }
    }
    
    func stopRecorder() {
        voiceImageView.isHidden = true
        asrClient.stopAsr()
        print("stopped")
    }
    
    @IBAction func fileRecognize(_ sender: Any) {
        let filePath = Bundle.main.path(forResource: "BAC009S0764W0121", ofType: "pcm")!
        let parentPath = URL(fileURLWithPath: filePath).deletingLastPathComponent().path
        let queue = DispatchQueue.global()
        queue.async { [self] in
            asrResource(withPath: parentPath) { ret, message in
                DispatchQueue.main.async {
                    self.view.makeToast(message,position: .center)
                }
            }
        }
    }
    
    // asr识别的随机性测试
    @IBAction func asrTestAction(_ sender: UIButton) {
        randomAsrStart()
    }
    
    func getResource(_ forResource: String, _ ofType: String) -> String {
        let path = Bundle.main.path(forResource: forResource, ofType: ofType)
        precondition(
            path != nil,
            "\(forResource).\(ofType) does not exist!\n" + "Remember to change \n"
            + "  Build Phases -> Copy Bundle Resources\n" + "to add it!"
        )
        return path!
    }
}

extension ViewController: DBAsrDelegate {
    
    func identifyTheCallback(_ message: String!, sentenceEnd: Bool) {
        print("[debug]:file Name: \(fileName)  message: \(message!), sentenceEnd: \(sentenceEnd)")
        convertFlag = false;
        let time = DBTimeUtil.end()
        DBTimeUtil().writeFile(fileName: fileName, content: message,time: time,totalTime: String(totalTime))
        if !message.isEmpty {
            self.lastSentence = message
            updateLabel()
        }
        if sentenceEnd {
            if !message.isEmpty {
                let tmp = self.lastSentence
                self.lastSentence = ""
                self.sentences.append(tmp)
            }
        }
    }
    func onError(_ code: Int, message: String!) {
        print("error code :\(code), message: \(String(describing: message))")
    }
    
    func dbValues(_ db: Int) {
        print("当前声音的能量值：\(db)")
        guard db > 0 && db < 100 else {
            print("当前获取的音量值超过合理范围")
            return
        }
        var imageName:String;
        if db < 30 {
            imageName = "1"
        }else if db < 40 {
            imageName = "2"
        }else if db < 50 {
            imageName = "3"
        }else if db < 55 {
            imageName = "4"
        }else if db < 60 {
            imageName = "5"
        }else if db < 70  {
            imageName = "6"
        }else if db < 80 {
            imageName = "7"
        }else {
            imageName = "8"
        }
        voiceImageView.image = UIImage.init(named: imageName)
    }
    
    func asrResource(withPath resPath: String, messageHandler:MessageHandler) {
        DBTimeUtil().path(forResource: resPath) { [weak self] isSucess, fullPath, dirPath in
            guard let self = self else {
                return
            }
            self.pathArray.append(fullPath)
        }

        let index = 0
        for fullPath in pathArray {
            while convertFlag {
                sleep(3)
            }
            guard index < pathArray.count else {
                return
            }
            convertFlag = true
            DBTimeUtil.start()
            fileName = URL(string: fullPath)!.lastPathComponent
            totalTime = DBTimeUtil.audioTotalTime(fullPath)
            let ret = asrClient.startAsr(withFilePath: fullPath)
            if ret == false {
                messageHandler(false,"请先获取授权信息");
            }
        }
    }
    
    // Asr 的测试代码
    func randomAsrStart() {
        let timeLength = arc4random() % 3600 + 10;
        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(timeLength), repeats: true) { timer in
            self.asrClient.logMessage("test timeLen:\(timeLength)")
            self.stopRecorder()
            self.startRecorder()
        }
        RunLoop.current.add(timer, forMode: .common)
        timer.fireDate = Date.distantPast
    }
    
}
