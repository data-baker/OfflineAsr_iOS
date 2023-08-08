//
//  DBListViewController.swift
//  DBOfflineAsr
//
//  Created by 林喜 on 2023/8/3.
//

import UIKit

class DBListViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let button = sender as! UIButton
        let desVC = segue.destination as! ViewController
        desVC.modalPresentationStyle = .fullScreen
        if ((button.titleLabel?.text?.hasPrefix("授权管理")) == true) {
            desVC.pageType = .authPage
        }
       else if ((button.titleLabel?.text?.hasPrefix("离线Asr识别")) == true) {
            desVC.pageType = .asr
            print("跳转离线Asr识别")
        }else if ((button.titleLabel?.text?.hasPrefix("录音文件识别")) == true) {
            print("跳转录音文件识别")
            desVC.pageType = .fileRecognize
        }
    }

}
