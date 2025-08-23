//
//  SNFlowControlAction.swift
//
//
//  Created by Lee Steve on 2025/5/5.
//
import Foundation

extension SNFlowControl {
    /// Called when the flow completes.
    /// 流程結束時的呼叫
    public typealias FinishedBlock = (_ finishByStyle: ActionStyle?) -> Void
    /// Calls the context to control whether the flow should continue or terminate.
    /// 呼叫 context 來控制流程是否繼續或終止
    public typealias ActionContextBlock = (_ actionContext: ActionStyle) -> Void
    /// Core step execution block. You must call context(.onNext / .onStop / .onFinished)
    /// 執行核心邏輯的區塊，必須呼叫 context 來控制流程是否繼續或終止
    public typealias StepBlock = (@escaping ActionContextBlock) -> Void
    /// A simplified step without flow control callback.
    /// 簡單的步驟邏輯，不需要手動控制流程
    public typealias ThenBlock = () -> Void
    /// Condition block returning Bool
    /// 判斷條件用區塊
    public typealias IfBlock = () -> Bool
    /// 隨時呼叫判斷條件用區塊
    public typealias IfAsyncBlock = ((Bool) -> Void) -> Void
    /// 巢狀呼叫判斷條件用區塊
    public typealias NestedThenBlock = (ThenBlock?) -> Void
    public typealias LogBlock = () -> Any
    /// Uses a block to evaluate a condition and returns an enum indicating the outcome.
    /// 判斷條件用區塊 回傳enum 狀態
    public typealias SwitchThenBlock<T> = (T,NestedThenBlock?) -> Void
    /// Uses a closure to evaluate a condition, returns an enum to indicate the result,
    /// and lets you manually control the flow based on that result.
    /// 判斷條件用區塊 回傳enum 狀態 並手動控制流程
    public typealias SwitchActionBlock<T> = (T, @escaping ActionContextBlock) -> Void
    /// Represents a single step in the flow.
    /// 表示流程中的單一步驟
    public class Action {
        public var id: String? = nil
        public var index: Int? = nil
        public let action: StepBlock
        public let onQueue: QueueStyle
        public init(
            id: String? = nil,
            index: Int? = nil,
            onQueue: QueueStyle = .none,
            action: @escaping StepBlock
        ) {
            self.id = id
            self.index = index
            self.onQueue = onQueue
            self.action = action
        }
        /// trigger action
        /// 執行 action
        public func command(actionStyleHandler: ActionContextBlock? = nil) {
            SNFlowControl.Action.queueHandle(onQueue: self.onQueue, action: {
                self.action { context in
                    guard let actionStyleHandler = actionStyleHandler else { return }
                    actionStyleHandler(context)
                }
            })
        }
    }
    
    public class AsyncAction : Action {
        public let isAsync: Bool = true
        public let asyncAction: StepBlock
        /// AsyncAction
        /// - Parameters:
        ///   - id: Async Action id
        ///   - index: Async Action index
        ///   - onQueue: Async Action use which queue
        ///   - asyncAction: async block
        init(
            id: String? = nil,
            index: Int? = nil,
            onQueue: QueueStyle = .none,
            asyncAction: @escaping StepBlock
        ) {
            self.asyncAction = asyncAction
            //   - action: internal block for continue next action but async action is waiting complete
            // 先讓原本flow流程繼續不阻塞
            super.init(id: id, index: index, onQueue: onQueue) { context in
                context(.onNext(nil))
            }
        }
        /// trigger action
        /// 執行 action
        public override func command(actionStyleHandler: ActionContextBlock? = nil) {
            super.command(actionStyleHandler: actionStyleHandler)
        }
    }
    
    public class BlockAction : Action {}
    /// Flow control options
    /// 控制流程的狀態選項
    public enum ActionStyle: Equatable {
        public static func == (lhs: SNFlowControl.ActionStyle, rhs: SNFlowControl.ActionStyle) -> Bool {
            switch (lhs, rhs) {
            case (.onNext(_), .onNext(_)):
                return true
            case (.onStop, .onStop):
                return true
            case (.onFinished, .onFinished):
                return true
            default:
                return false
            }
        }
        /// syncAction:  make sure update output value thread safe
        case onNext(_ syncAction: ThenBlock?)
        /// syncAction:  make sure update output value thread safe
        case onStop(_ syncAction: ThenBlock?)
        /// syncAction:  make sure update output value thread safe
        case onFinished(_ syncAction: ThenBlock?)
    }
    /// Defines which queue the step should execute on.
    /// 控制任務在哪個 Queue 上執行
    public enum QueueStyle: Equatable {
        /// Main thread / 主線程
        case main(createStyle: QueueCreateStyle)
        /// Background global queue / 背景執行緒
        case global(createStyle: QueueCreateStyle)
        /// Custom queue / 自己的queue
        case custom(queue: DispatchQueue)
        ///  No queue switching, use current serial background queue / 不切換 Queue 沿用當前serial background queue
        case none
    }
    /// Strategy for whether to create a new queue or reuse the current one.
    /// 決定是否建立新的佇列或重用當前佇列的策略
    public enum QueueCreateStyle: Equatable {
        /// Always create a new async queue.
        /// 建立新的async queue
        case new
        /// Reuse the current queue if already matches the target style.
        /// 沿用當前同個queue 如果不是目標的queue style會檢查來決定要不要建立新的queue
        case none
    }
    /// Strategy for whether to Sync Action
    /// 決定使用哪個當作同步工具
    public enum SyncStyle: Equatable {
        /// Use Lock to sync action
        /// 使用lock來同步action
        case lock
        /// Use GCD serialQueue to sync action
        /// 使用GCD serialQueue來同步action
        case serialQueue
    }
}

// MARK: SNFlowControl Action Flow 主要 DSL 工具函式
extension SNFlowControl.Action {
    /// Perform different actions based on the passed-in enum, the flow continues to the next step  default is background thread
    /// 根據傳入enum 處理不同action 並直接繼續下一個步驟 預設背景queue
    public static func switchThen<T>(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        state: T,
        stateAction: @escaping SNFlowControl.SwitchThenBlock<T>
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            let doAction = {
                actionStyle(.onNext({
                    stateAction(state, { action in
                        action?()
                    })
                }))
            }
            queueHandle(onQueue: onQueue, action: doAction)
        }
    }
    /// Handles different actions based on the given enum value,
    /// and allows custom handling of the completion behavior. default is background thread
    /// 根據傳入enum 處理不同action 並可自行決定結束動作 預設背景queue
    public static func switchAction<T>(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        state: T,
        stateAction: @escaping SNFlowControl.SwitchActionBlock<T>
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            let doAction = {
                stateAction(state, actionStyle)
            }
            queueHandle(onQueue: onQueue, action: doAction)
        }
    }
    /// Conditional block
    /// - If `condition` is true, the flow continues to the next step;
    ///   if false, the flow is interrupted. default is background thread
    /// 條件判斷區塊
    /// - 如果為 condition 為 true 則繼續下一步，false 則中斷流程 預設背景queue
    public static func ifNext(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        condition: @escaping SNFlowControl.IfBlock
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            switch condition() {
            case true:
                actionStyle(.onNext(nil))
            case false:
                actionStyle(.onStop(nil))
            }
        }
    }
    
    /// async Conditional block
    /// - If `condition` is true, the flow continues to the next step;
    ///   if false, the flow is interrupted. default is background thread
    /// 非同步條件判斷區塊
    /// - 如果為 condition 為 true 則繼續下一步，false 則中斷流程 預設背景queue
    public static func ifNextAsync(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        asyncCondition: @escaping SNFlowControl.IfAsyncBlock
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            asyncCondition({ condition in
                switch condition {
                case true:
                    actionStyle(.onNext(nil))
                case false:
                    actionStyle(.onStop(nil))
                }
            })
        }
    }
    
    
    /// Conditional block
    /// - If `condition` is true, the flow is interrupted;
    ///   if false, the flow continues to the next step. default is background thread
    /// 條件判斷區塊
    /// - 如果為 condition 為 true 則中斷流程，false 則繼續下一步 預設背景queue
    public static func ifStop(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        condition: @escaping SNFlowControl.IfBlock
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            switch condition() {
            case true:
                actionStyle(.onStop(nil))
            case false:
                actionStyle(.onNext(nil))
            }
        }
    }
    
    /// async Conditional block
    /// - If `condition` is true, the flow is interrupted;
    ///   if false, the flow continues to the next step. default is background thread
    ///   Execution will wait and return when you decide.
    /// 非同步條件判斷區塊 可自行決定何時返回 會等待
    /// - 如果為 condition 為 true 則中斷流程，false 則繼續下一步 預設背景queue
    public static func ifStopAsync(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        asyncCondition: @escaping SNFlowControl.IfAsyncBlock
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            asyncCondition({ condition in
                switch condition {
                case true:
                    actionStyle(.onStop(nil))
                case false:
                    actionStyle(.onNext(nil))
                }
            })
        }
    }
    
    /// Conditional block
    /// - If `condition` is true, the action will be executed;
    ///   if false, it will not be executed. default is background thread
    /// 條件判斷區塊
    /// - 如果 condition 為 true 則執行Action，false 不執行 預設背景queue
    public static func ifThen(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        condition: @escaping SNFlowControl.IfBlock,
        action: @escaping SNFlowControl.ThenBlock
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            let doAction = {
                actionStyle(.onNext({
                    if (condition()) {
                        action()
                    }
                }))
            }
            queueHandle(onQueue: onQueue, action: doAction)
        }
    }
    /// Conditional block
    /// - If `condition` is true, the IF action will be executed;
    ///   if false, the ELSE action will be executed.  default is background thread
    /// 條件判斷區塊
    /// - 如果 condition 為 true 則執行IF Action，false 執行Else Action 預設背景queue
    public static func ifElseThen(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        condition: @escaping SNFlowControl.IfBlock,
        ifAction: @escaping SNFlowControl.ThenBlock,
        elseAction: @escaping SNFlowControl.ThenBlock
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            let doAction = {
                actionStyle(.onNext({
                    switch condition() {
                    case true:
                        ifAction()
                    default:
                        elseAction()
                    }
                }))
            }
            queueHandle(onQueue: onQueue, action: doAction)
        }
    }
    /// Simple step without flow control.
    /// Allows specifying the execution thread and creation method. default is background thread
    /// 簡單步驟，不帶流程控制
    /// 可指定執行緒與建立方式 預設背景queue
    public static func then(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        action: @escaping SNFlowControl.ThenBlock
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            let doAction = {
                actionStyle(.onNext({
                    action()
                }))
            }
            queueHandle(onQueue: onQueue, action: doAction)
        }
    }
    /// Simple step for logging.
    /// 記錄 Log 的簡單步驟
    public static func log(
        id: String? = nil,
        index: Int? = nil,
        _ items: @autoclosure @escaping SNFlowControl.LogBlock
        //_ items: Any...
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            actionStyle(.onNext({
                print("SNLog: \(items())")
            }))
        }
    }
    /// Delay for a certain duration before continuing.
    /// Allows specifying the queue and delay time in seconds. default is background thread
    /// 延遲一定時間再繼續
    /// 可指定 Queue 與延遲秒數 預設背景queue
    public static func delay(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle,
        seconds: TimeInterval
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            switch onQueue {
            case .main(let createStyle):
                DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                    actionStyle(.onNext(nil))
                }
            case .global(let createStyle):
                DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                    actionStyle(.onNext(nil))
                }
            case .custom(queue: let queue):
                queue.asyncAfter(deadline: .now() + seconds) {
                    actionStyle(.onNext(nil))
                }
            case .none:
                actionStyle(.onNext(nil))
            }
        }
    }
    /// async action  default is background thread
    /// 非同步執行 預設背景queue
    public static func asyncAction(
        logItems: Any...,
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        action: @escaping SNFlowControl.StepBlock
    ) -> SNFlowControl.AsyncAction{
        return SNFlowControl.AsyncAction(
            id: id,
            index: index,
            asyncAction: { actionBlock in
                if (!logItems.isEmpty) {
                    print("SNLog: \(logItems)")
                }
                queueHandle(onQueue: onQueue) {
                    action { actionContext in
                        actionBlock(actionContext)
                    }
                }
            })
    }
    /// wait Unit before all  Async Task Finished
    /// 等到前面全部非同步完成才繼續後面的
    public static func waitUntilAllAsyncTaskFinished() -> SNFlowControl.BlockAction{
        return SNFlowControl.BlockAction(action: {_ in})
    }
}
// MARK: Private - Method
extension SNFlowControl.Action {
    static func queueHandle(onQueue: SNFlowControl.QueueStyle, action: @escaping SNFlowControl.ThenBlock) {
        switch onQueue {
        case .main(let createStyle):
            let doMainAction = {
                DispatchQueue.main.async {
                    action()
                }
            }
            switch createStyle {
            case .new:
                doMainAction()
            case .none:
                guard Thread.isMainThread else {
                    doMainAction()
                    return
                }
                action()
            }
        case .global(let createStyle):
            let doGlobalAction = {
                DispatchQueue.global().async {
                    action()
                }
            }
            switch createStyle {
            case .new:
                doGlobalAction()
            case .none:
                guard Thread.isGlobalThread else {
                    doGlobalAction()
                    return
                }
                action()
            }
        case .custom(queue: let queue):
            queue.async {
                action()
            }
        case .none:
            action()
        }
    }
}
