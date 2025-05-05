//
//  ViewController.swift
//  SNFlowControlExample
//
//  Created by Lee Steve on 2025/5/6.
//

import UIKit
import SNFlowControl

typealias SNAction = SNFlowControl.Action

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.example1()
    }
    
    // Create Flow Control Use Builder Like SwiftUI
    // remember add start() in the end make flow start
    // SNFlowControl -> flow control manager
    // SNFlowControl.Action -> flow action
    func example1() {
        SNFlowControl {
            SNAction { context in
                print("step1")
                context(.onNext)
            }
            
            SNAction.log("record")
            
            SNAction.then(onQueue: .none) {
                print("do stuff")
            }
            
            SNAction.delay(onQueue: .main(createStyle: .none), seconds: 3)
            
            SNAction.log("after delay 3 seconds")
            // if return false make flow finished
            SNAction.if {
                return true
            }
            // async action
            SNAction { context in
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    context(.onNext)
                }
            }
            
            SNAction.log("wait until async action finished ")
            
        } finished: {
            print("flow control end")
        }.start()
    }
}


