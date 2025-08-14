//
//  SNFlowControl.swift
//
//
//  Created by Lee Steve on 2025/5/5.
//
import Foundation
/// SNFlowControl
///
/// A lightweight chain-based flow controller inspired by SwiftUI's DSL style.
/// You can compose multiple synchronous or asynchronous actions using builder syntax,
/// and control flow with `.onNext`, `.onStop`, or `.onFinished`.
/// Final action triggers the `finished` callback.
///
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
    /// Called when change to next action
    /// 準備執行下一個 action 時的 index
    let progressActionIndexChange: ((_ actionIndex: Int) -> Void)?
    /// Current executing index
    /// 當前執行到的動作索引
    public var currentIndex = 0
    /// Current executing id
    /// 當前執行到的動作id
    public var currentID = ""
    /// is Progressing action
    /// 當前是否正在執行中
    public var isProgressing = false
    /// specifies the queue on which the `finished` block will be executed
    /// finished完成時在哪個queue執行
    public var finishedQueueStyle: SNFlowControl.QueueStyle = .none
    lazy var isFinished: Bool = false
    lazy var progressAsyncTasksCount: Int = 0
    lazy var blockIndex: Int? = nil
    /// Initialize with a fixed array of actions
    /// 使用動作陣列初始化
    /// - Parameters:
    ///   - actios: Actions to execute
    ///   - progressActionIndexChange: progress action index
    ///   - receiveFinishOnQueue: specifies the queue on which the `finished` block will be executed
    ///   - finished: Called when all actions finish or the flow is stopped.
    public init(
        actios: [Action],
        progressActionIndexChange: ((_ actionIndex: Int) -> Void)? = nil,
        receiveFinishOnQueue: SNFlowControl.QueueStyle = .none,
        finished: FinishedBlock? = nil
    ) {
        self.actios = actios
        self.progressActionIndexChange = progressActionIndexChange
        self.finishedQueueStyle = receiveFinishOnQueue
        self.finished = finished
    }
    /// Initialize with a DSL of actions
    /// 使用DSL初始化
    /// - Parameters:
    ///   - actios: Actions to execute
    ///   - progressActionIndexChange: progress action index
    ///   - receiveFinishOnQueue: specifies the queue on which the `finished` block will be executed
    ///   - finished: Called when all actions finish or the flow is stopped.
    public init(
        @SNFlowControlActionBuilder builderActios: () -> [Action],
        progressActionIndexChange: ((_ actionIndex: Int) -> Void)? = nil,
        receiveFinishOnQueue: SNFlowControl.QueueStyle = .none,
        finished: FinishedBlock? = nil
    ) {
        self.actios = builderActios()
        self.progressActionIndexChange = progressActionIndexChange
        self.finishedQueueStyle = receiveFinishOnQueue
        self.finished = finished
    }
    
    deinit {
        //print("deinit")
    }
    
    /// Start the flow. Will execute actions in order.
    /// 啟動流程，依序執行所有動作
    @discardableResult
    public func start() -> Self {
        //print("start action: \(self.index)")
        self.execute(targetIndex: self.currentIndex)
        return self
    }
    /// Will execute actions in order.
    /// 依序執行所有動作
    private func execute(targetIndex: Int) {
        //print("start action: \(self.index)")
        func finishAction(style: SNFlowControl.ActionStyle?) {
            SNFlowControl.Action.queueHandle(onQueue: self.finishedQueueStyle) {
                self.finished?(style)
                self.isFinished = true
                self.isProgressing = false
            }
        }
        
        func hasAsync() -> Bool {
            return self.progressAsyncTasksCount > 0
        }
        
        func checkFinishAction(style: SNFlowControl.ActionStyle?) {
            if !hasAsync() && !self.isFinished {
                finishAction(style: style)
            }
        }
        
        func next() {
            self.execute(targetIndex: targetIndex + 1)
        }
        
        func blockToContinue(targetIndex: Int) {
            self.blockIndex = nil
            self.execute(targetIndex: targetIndex)
        }
        
        guard let firstAction = self.actios[safe: targetIndex] else {
            checkFinishAction(style: .onFinished)
            return
        }
        self.currentIndex = targetIndex
        self.progressActionIndexChange?(targetIndex)
        self.isProgressing = true
        self.currentID = firstAction.id ?? "\(self.currentID)"
        
        if let asyncAction = firstAction as? AsyncAction {
            self.progressAsyncTasksCount += 1
            asyncAction.asyncAction { actionContext in
                // 把自己移除隊列
                self.progressAsyncTasksCount -= 1
                switch actionContext {
                case .onNext:
                    // 沒有等待中的async 結束
                    if !hasAsync() {
                        // 確認是否是有wait until before task完成
                        if let blockIndex = self.blockIndex {
                            blockToContinue(targetIndex: blockIndex + 1)
                            return
                        }
                        // 沒有使用 wait until before task 表示執行完畢
                        checkFinishAction(style: .onFinished)
                        return
                    }
                    return
                case .onStop, .onFinished:
                    guard !self.isFinished else {return}
                    finishAction(style: actionContext)
                    return
                }
            }
            next()
            return
        }
        
        if firstAction is BlockAction {
            //print("BlockAction: \(targetIndex)")
            if (hasAsync()) {
                self.blockIndex = targetIndex
            } else {
                blockToContinue(targetIndex: targetIndex + 1)
            }
            return
        }
        
        firstAction.command { actionContext in
            //print(actionContext)
            switch actionContext {
            case .onNext:
                next()
                return
            case .onStop, .onFinished:
                guard !self.isFinished else {return}
                finishAction(style: actionContext)
                return
            }
        }
    }
}
