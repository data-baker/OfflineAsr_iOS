//
//  DBTimeUtil.swift
//
//  Created by 林喜 on 2023/6/1.
//

import UIKit

typealias ResultBlock = (Bool, String, String) -> Void

class DBTimeUtil: NSObject {
    static var startTime:CFAbsoluteTime?
    static func start() {
        startTime = CFAbsoluteTimeGetCurrent()
    }
    static func end()->String {
        let time = CFAbsoluteTimeGetCurrent() - startTime!
        let message = String(format: "消耗时间:%.3f", time)
        print(message)
        return message
    }
    
    // 获取音频的时常
    static func audioTotalTime(_ path:String)->Double {
        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            let sampleRate = 16000
            let bitDepth = 16
            let numChannels = 1
            let dataSize = data.count
            let duration = Double(dataSize) / (Double(numChannels) * Double(bitDepth) / 8 * Double(sampleRate))
            print(duration) // Output: 4.0
            return duration
        }catch {
            print("计算失败")
            return 0
        }
    }
    
    func path(forResource path: String, complete: @escaping ResultBlock) {
        let fileManager = FileManager.default
        guard let arraySor = try? fileManager.contentsOfDirectory(atPath: path), !arraySor.isEmpty else {
            return
        }
        arraySor.forEach { fileName in
            if fileName.hasPrefix(".") {
                return
            }
            if !fileName.hasSuffix("pcm") {
                return
            }
            let fullPath = (path as NSString).appendingPathComponent(fileName)
            var isFolder: ObjCBool = false
            let isExist = fileManager.fileExists(atPath: fullPath, isDirectory: &isFolder)
            if isExist {
                if isFolder.boolValue {
                    self.path(forResource: fullPath, complete: complete)
                } else {
                    complete(true, fullPath, (path as NSString).lastPathComponent)
                }
            }
        }
    }
    
    /// save data to file
    func writeFile(fileName:String, content:String,time:String,totalTime:String) {
        let contents = String(format: "%@\t%@\n", fileName,content)
        saveCriticalSDKRunData(contents, fileName: "DBRunLog.txt")
        let timeMsg = String(format: "%@\t%@\t%@\t%@\n",fileName,content,time,totalTime)
        saveCriticalSDKRunData(timeMsg, fileName: "DBRunLog_time.txt")
    }
    
    func saveCriticalSDKRunData(_ string: String, fileName:String) {
        let docPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let filePath = (docPath as NSString).appendingPathComponent(fileName)
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: filePath) {
            let initialContent = ">>>>>>程序运行日志<<<<<<<<\n"
            try? initialContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        }
        
        if let handle = FileHandle(forUpdatingAtPath: filePath) {
            handle.seekToEndOfFile()
            let logString = String(format: "%@\n", string)
            handle.write(logString.data(using: .utf8)!)
            handle.closeFile()
        } else {
            NSLog("Failed to open file at path: \(filePath)")
        }
    }
}
