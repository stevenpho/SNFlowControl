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
    private let actios: [Action]
    /// Called when all actions finish or the flow is stopped.
    /// 所有流程執行完畢或中斷時會呼叫的完成區塊
    private let finished: SNFlowControl.FinishedBlock?
    /// Called when change to next action
    /// 準備執行下一個 action 時的 index
    private let progressActionIndexChange: ((_ actionIndex: Int) -> Void)?
    /// Sync Queue
    /// 同步專用Queue
    private let serialQueue: DispatchQueue?
    /// Sync Queue Key
    /// 同步專用Queue 的識別Key
    private let flowProcessingKey: DispatchSpecificKey<String>?
    /// Sync Queue Name
    /// 同步專用Queue 的識別Name
    private let flowProcessingName: String?
    /// Sync Lock
    /// 同步專用 鎖
    private let lock: NSRecursiveLock?
    /// 使用的同步類型
    private let syncStyle: SNFlowControl.SyncStyle
    /// 當前總共有幾個非同步action
    /// how many async action for now
    private var progressAsyncTasksCount = 0
    /// Current executing index
    /// 當前執行到的動作索引
    public private(set) var currentIndex = 0
    /// Current executing id
    /// 當前執行到的動作id
    public private(set) var currentID = ""
    /// is Progressing action
    /// 當前是否正在執行中
    public private(set) var isProgressing = false
    /// specifies the queue on which the `finished` block will be executed
    /// finished完成時在哪個queue執行
    public var finishedQueueStyle: SNFlowControl.QueueStyle = .none
    /// flow action finished all actions
    /// 已經完成全部action
    public private(set) var isFinished = false
    /// which index will block until async task finished
    /// 當前執行到哪一個index是要等到非同步全部都完成的
    public private(set) var blockIndex: Int?
    /// Initialize with a fixed array of actions
    /// 使用動作陣列初始化
    /// - Parameters:
    ///   - syncStyle: choose sync style:  default is lock
    ///   - actios: Actions to execute
    ///   - progressActionIndexChange: progress action index
    ///   - receiveFinishOnQueue: specifies the queue on which the `finished` block will be executed
    ///   - finished: Called when all actions finish or the flow is stopped.
    public init(
        syncStyle: SNFlowControl.SyncStyle = .lock,
        actios: [Action],
        progressActionIndexChange: ((_ actionIndex: Int) -> Void)? = nil,
        receiveFinishOnQueue: SNFlowControl.QueueStyle = .none,
        finished: SNFlowControl.FinishedBlock? = nil
    ) {
        self.syncStyle = syncStyle
        self.actios = actios
        self.progressActionIndexChange = progressActionIndexChange
        self.finishedQueueStyle = receiveFinishOnQueue
        self.finished = finished
        
        switch syncStyle {
        case .lock:
            self.lock = NSRecursiveLock()
            self.serialQueue = nil
            self.flowProcessingKey = nil
            self.flowProcessingName = nil
        case .serialQueue:
            self.lock = nil
            let processingKey = DispatchSpecificKey<String>()
            let processingName = "snflowcontrol.flow.serialQueue.\(UUID().uuidString)"
            self.serialQueue = DispatchQueue(label: "com.snflowcontrol.flow.serialQueue")
            self.flowProcessingKey = processingKey
            self.flowProcessingName = processingName
            self.serialQueue?.setSpecific(key: processingKey, value: processingName)
        }
    }
    /// Initialize with a fixed array of actions
    /// 使用動作陣列初始化
    /// - Parameters:
    ///   - syncStyle: choose sync style:  default is lock
    ///   - actios: Actions to execute
    ///   - progressActionIndexChange: progress action index
    ///   - receiveFinishOnQueue: specifies the queue on which the `finished` block will be executed
    ///   - finished: Called when all actions finish or the flow is stopped.
    public init(
        syncStyle: SNFlowControl.SyncStyle = .lock,
        @SNFlowControlActionBuilder builderActios: () -> [Action],
        progressActionIndexChange: ((_ actionIndex: Int) -> Void)? = nil,
        receiveFinishOnQueue: SNFlowControl.QueueStyle = .none,
        finished: SNFlowControl.FinishedBlock? = nil
    ) {
        self.syncStyle = syncStyle
        self.actios = builderActios()
        self.progressActionIndexChange = progressActionIndexChange
        self.finishedQueueStyle = receiveFinishOnQueue
        self.finished = finished
        switch syncStyle {
        case .lock:
            self.lock = NSRecursiveLock()
            self.serialQueue = nil
            self.flowProcessingKey = nil
            self.flowProcessingName = nil
        case .serialQueue:
            self.lock = nil
            let processingKey = DispatchSpecificKey<String>()
            let processingName = "snflowcontrol.flow.serialQueue.\(UUID().uuidString)"
            self.serialQueue = DispatchQueue(label: "com.snflowcontrol.flow.serialQueue")
            self.flowProcessingKey = processingKey
            self.flowProcessingName = processingName
            self.serialQueue?.setSpecific(key: processingKey, value: processingName)
        }
    }
    
    deinit {
        //print("deinit")
        // TODO: add interrupt call
//        if !self.isFinished {
//            self.finished?(nil)
//        }
//        if !self.isFinished && self.finished != nil {
//            let finishedBlock = self.finished
//            let queueStyle = self.finishedQueueStyle
//            SNFlowControl.Action.queueHandle(onQueue: queueStyle) {
//                finishedBlock?(nil)
//            }
//        }
    }

    
    @discardableResult
    public func start() -> Self {
        switch syncStyle {
        case .lock:
            withLock {
                executeLockStyle(targetIndex: currentIndex)
            }
        case .serialQueue:
            withFlowQueue {
                self.executeSerialQueueStyle(targetIndex: self.currentIndex)
            }
        }
        return self
    }

}

// MARK: Lock Style
extension SNFlowControl {
    
    @discardableResult
    private func withLock<T>(_ body: () -> T) -> T {
        lock?.lock(); defer { lock?.unlock() }
        return body()
    }
    
    private var hasAsync: Bool {
        withLock { progressAsyncTasksCount > 0 }
    }
    
    private func executeLockStyle(targetIndex: Int) {
        guard let action = actios[safe: targetIndex] else {
            if !hasAsync && !isFinished {
                finishActionLockStyle(style: .onFinished(nil))
            }
            return
        }

        withLock {
            currentIndex = targetIndex
            currentID = action.id ?? currentID
            isProgressing = true
            progressActionIndexChange?(targetIndex)
        }

        if let asyncAction = action as? AsyncAction {
            withLock { progressAsyncTasksCount += 1 }

            asyncAction.asyncAction { context in
                var shouldFinish = false
                var blockNext: (() -> Void)?

                self.withLock {
                    self.progressAsyncTasksCount -= 1

                    switch context {
                    case .onNext(let nextAction):
                        nextAction?()
                        if !self.hasAsync {
                            if let block = self.blockIndex {
                                self.blockIndex = nil
                                blockNext = { self.executeLockStyle(targetIndex: block + 1) }
                            } else if self.currentIndex == self.actios.count - 1 {
                                shouldFinish = !self.hasAsync && !self.isFinished
                            }
                        }
                    case .onStop(let stopAction):
                        stopAction?()
                        if !self.isFinished {
                            shouldFinish = true
                        }
                    case .onFinished(let finishedAction):
                        finishedAction?()
                        if !self.isFinished {
                            shouldFinish = true
                        }
                    }
                }

                if shouldFinish {
                    self.finishActionLockStyle(style: .onFinished(nil))
                } else if let blockNext = blockNext {
                    blockNext()
                }
            }
            executeLockStyle(targetIndex: targetIndex + 1)
            return
        }

        if action is BlockAction {
            withLock {
                if hasAsync {
                    blockIndex = targetIndex
                } else {
                    blockIndex = nil
                    executeLockStyle(targetIndex: targetIndex + 1)
                }
            }
            return
        }

        action.command { context in
            var shouldFinish = false

            self.withLock {
                switch context {
                case .onNext(let nextAction):
                    nextAction?()
                    self.executeLockStyle(targetIndex: targetIndex + 1)
                case .onStop(let stopAction):
                    stopAction?()
                    if !self.isFinished {
                        shouldFinish = true
                    }
                case .onFinished(let finishedAction):
                    finishedAction?()
                    if !self.isFinished {
                        shouldFinish = true
                    }
                }
            }

            if shouldFinish {
                self.finishActionLockStyle(style: context)
            }
        }
    }
    
    private func finishActionLockStyle(style: SNFlowControl.ActionStyle?) {
        self.withLock {
            guard !self.isFinished else { return }
            self.isFinished = true
            self.isProgressing = false
        }
        SNFlowControl.Action.queueHandle(onQueue: finishedQueueStyle) {
            self.finished?(style)
        }
    }
}

// MARK: GCD SerialQueue Style
extension SNFlowControl {
    
    private func withFlowQueue(_ body: @escaping ThenBlock) {
        guard self.isCurrentQueue() else {
            self.serialQueue?.async(execute: body)
            return
        }
        body()
    }
    
    private func isCurrentQueue() -> Bool {
        guard let flowProcessingKey = self.flowProcessingKey else {
            return false
        }
        return DispatchQueue.getSpecific(key: flowProcessingKey) == self.flowProcessingName
    }
    /// Will execute actions in order.
    /// 依序執行所有動作
    private func executeSerialQueueStyle(targetIndex: Int) {
        func finishActionSerialQueueStyle(style: SNFlowControl.ActionStyle?) {
            SNFlowControl.Action.queueHandle(onQueue: self.finishedQueueStyle) {
                self.withFlowQueue {
                    self.isFinished = true
                    self.isProgressing = false
                    self.finished?(style)
                }
            }
        }
        
        func hasAsync() -> Bool {
            return self.progressAsyncTasksCount > 0
        }
        
        func checkFinishAction(style: SNFlowControl.ActionStyle?) {
            if !hasAsync() && !self.isFinished {
                finishActionSerialQueueStyle(style: style)
            }
        }
        
        func next() {
            self.withFlowQueue {
                self.executeSerialQueueStyle(targetIndex: targetIndex + 1)
            }
        }
        
        func blockToContinue(targetIndex: Int) {
            self.withFlowQueue {
                self.blockIndex = nil
                self.executeSerialQueueStyle(targetIndex: targetIndex)
            }
        }
        
        guard let firstAction = self.actios[safe: targetIndex] else {
            self.withFlowQueue {
                checkFinishAction(style: .onFinished(nil))
            }
            return
        }
        self.currentIndex = targetIndex
        self.progressActionIndexChange?(targetIndex)
        self.isProgressing = true
        self.currentID = firstAction.id ?? "\(self.currentID)"
        
        if let asyncAction = firstAction as? AsyncAction {
            self.withFlowQueue {
                self.progressAsyncTasksCount += 1
                asyncAction.asyncAction { actionContext in
                    self.withFlowQueue {
                        // 把自己移除隊列
                        self.progressAsyncTasksCount -= 1
                        switch actionContext {
                        case .onNext(let action):
                            action?()
                            // 沒有等待中的async 結束
                            if !hasAsync() {
                                // 確認是否是有wait until before task完成
                                if let blockIndex = self.blockIndex {
                                    blockToContinue(targetIndex: blockIndex + 1)
                                    return
                                }
                                guard self.currentIndex == self.actios.count - 1 else {return}
                                // 沒有使用 wait until before task 表示執行完畢
                                checkFinishAction(style: .onFinished(nil))
                                return
                            }
                            return
                        case .onStop(let stopAction):
                            stopAction?()
                            guard !self.isFinished else {return}
                            finishActionSerialQueueStyle(style: actionContext)
                            return
                        case .onFinished(let finishedAction):
                            finishedAction?()
                            guard !self.isFinished else {return}
                            finishActionSerialQueueStyle(style: actionContext)
                            return
                        }
                    }
                }
                next()
            }
            return
        }
        
        if firstAction is BlockAction {
            self.withFlowQueue {
                if (hasAsync()) {
                    self.blockIndex = targetIndex
                } else {
                    blockToContinue(targetIndex: targetIndex + 1)
                }
            }
            return
        }
        
        firstAction.command { actionContext in
            self.withFlowQueue {
                switch actionContext {
                case .onNext(let action):
                    action?()
                    next()
                    break
                case .onStop(let stopAction):
                    stopAction?()
                    guard !self.isFinished else {break}
                    finishActionSerialQueueStyle(style: actionContext)
                    break
                case .onFinished(let finishedAction):
                    finishedAction?()
                    guard !self.isFinished else {break}
                    finishActionSerialQueueStyle(style: actionContext)
                    break
                }
            }
        }
    }
}
