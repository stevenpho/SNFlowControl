//
//  SNFlowControl.swift
//  
//
//  Created by Lee Steve on 2025/5/5.
//
import Foundation
/// SNFlowControl
///
/// EN:
/// A lightweight chain-based flow controller inspired by SwiftUI's DSL style.
/// You can compose multiple synchronous or asynchronous actions using builder syntax,
/// and control flow with `.onNext`, `.onStop`, or `.onFinished`.
/// Final action triggers the `finished` callback.
///
/// ZH:
/// 一個輕量的鏈式流程控制器，靈感來自 SwiftUI 的 DSL 語法風格。
/// 可透過 builder 語法組合多個同步或非同步動作，
/// 並透過 `.onNext`、`.onStop`、`.onFinished` 控制流程前進、停止或結束。
/// 最後會呼叫 `finished` 結尾處理。
public class SNFlowControl {
    /// The array of actions to be executed in sequence.
    /// 要依序執行的動作陣列
    let actios: [Action]
    /// Called when all actions finish or the flow is stopped.
    /// 所有流程執行完畢或中斷時會呼叫的完成區塊
    let finished: FinishedBlock?
    /// Current executing index
    /// 當前執行到的動作索引
    var index = 0
    /// Initialize with a fixed array of actions
    /// 使用動作陣列初始化
    /// - Parameters:
    ///   - actios: Actions to execute
    public init(actios: [Action], finished: FinishedBlock? = nil) {
        self.actios = actios
        self.finished = finished
    }
    /// Initialize with a DSL of actions
    /// 使用DSL初始化
    /// - Parameters:
    ///   - actios: Actions to execute
    public init(@SNFlowControlActionBuilder builderActios: () -> [Action], finished: FinishedBlock? = nil) {
        self.actios = builderActios()
        self.finished = finished
    }
    /// Start the flow. Will execute actions in order.
    /// 啟動流程，依序執行所有動作
    public func start() {
        //print("start action: \(self.index)")
        guard let firstAction = self.actios[safe: self.index] else {
            self.finished?()
            return
        }
        firstAction.action { actionContext in
            //print(actionContext)
            switch actionContext {
            case .onNext:
                self.index += 1
                self.start()
                return
            case .onStop, .onFinished:
                self.finished?()
                return
            }
        }
    }
}
