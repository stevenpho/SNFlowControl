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
    /// Uses a block to evaluate a condition and returns an enum indicating the outcome.
    /// 判斷條件用區塊 回傳enum 狀態
    public typealias SwitchThenBlock<T: CaseIterable> = (T) -> Void
    /// Uses a closure to evaluate a condition, returns an enum to indicate the result,
    /// and lets you manually control the flow based on that result.
    /// 判斷條件用區塊 回傳enum 狀態 並手動控制流程
    public typealias SwitchActionBlock<T: CaseIterable> = (T, @escaping ActionContextBlock) -> Void
    /// Represents a single step in the flow.
    /// 表示流程中的單一步驟
    public class Action {
        public var id: String? = nil
        public var index: Int? = nil
        public let action: StepBlock
        public init(id: String? = nil, index: Int? = nil,action: @escaping StepBlock) {
            self.id = id
            self.index = index
            self.action = action
        }
        /// trigger action
        /// 執行 action
        public func command(actionStyleHandler: ActionContextBlock? = nil) {
            self.action { context in
                guard let actionStyleHandler = actionStyleHandler else { return }
                actionStyleHandler(context)
            }
        }
    }
    
    public class AsyncAction : Action {
        public let isAsync: Bool = true
        public let asyncAction: StepBlock
        init(id: String? = nil, index: Int? = nil, asyncAction: @escaping StepBlock, action: @escaping StepBlock) {
            self.asyncAction = asyncAction
            super.init(id: id, index: index, action: action)
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
        case onNext
        case onStop
        case onFinished
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
        ///  No queue switching, use current queue / 不切換 Queue 沿用當前queue
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
}

// MARK: SNFlowControl Action Flow 主要 DSL 工具函式
extension SNFlowControl.Action {
    /// Perform different actions based on the passed-in enum, the flow continues to the next step
    /// 根據傳入enum 處理不同action 並直接繼續下一個步驟
    public static func switchThen<T: CaseIterable>(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        state: T,
        stateAction: @escaping SNFlowControl.SwitchThenBlock<T>
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            let doAction = {
                stateAction(state)
                actionStyle(.onNext)
            }
            queueHandle(onQueue: onQueue, action: doAction)
        }
    }
    /// Handles different actions based on the given enum value,
    /// and allows custom handling of the completion behavior.
    /// 根據傳入enum 處理不同action 並可自行決定結束動作
    public static func switchAction<T: CaseIterable>(
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
    ///   if false, the flow is interrupted.
    /// 條件判斷區塊
    /// - 如果為 condition 為 true 則繼續下一步，false 則中斷流程
    public static func ifNext(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        condition: @escaping SNFlowControl.IfBlock
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            switch condition() {
            case true:
                actionStyle(.onNext)
            case false:
                actionStyle(.onStop)
            }
        }
    }
    /// Conditional block
    /// - If `condition` is true, the flow is interrupted;
    ///   if false, the flow continues to the next step.
    /// 條件判斷區塊
    /// - 如果為 condition 為 true 則中斷流程，false 則繼續下一步
    public static func ifStop(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        condition: @escaping SNFlowControl.IfBlock
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            switch condition() {
            case true:
                actionStyle(.onStop)
            case false:
                actionStyle(.onNext)
            }
        }
    }
    /// Conditional block
    /// - If `condition` is true, the action will be executed;
    ///   if false, it will not be executed.
    /// 條件判斷區塊
    /// - 如果 condition 為 true 則執行Action，false 不執行
    public static func ifThen(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        condition: @escaping SNFlowControl.IfBlock,
        action: @escaping SNFlowControl.ThenBlock
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            let doAction = {
                if (condition()) {
                    action()
                }
                actionStyle(.onNext)
            }
            queueHandle(onQueue: onQueue, action: doAction)
        }
    }
    /// Conditional block
    /// - If `condition` is true, the IF action will be executed;
    ///   if false, the ELSE action will be executed.
    /// 條件判斷區塊
    /// - 如果 condition 為 true 則執行IF Action，false 執行Else Action
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
                switch condition() {
                case true:
                    ifAction()
                default:
                    elseAction()
                }
                actionStyle(.onNext)
            }
            queueHandle(onQueue: onQueue, action: doAction)
        }
    }
    /// Simple step without flow control.
    /// Allows specifying the execution thread and creation method.
    /// 簡單步驟，不帶流程控制
    /// 可指定執行緒與建立方式
    public static func then(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        action: @escaping SNFlowControl.ThenBlock
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            let doAction = {
                action()
                actionStyle(.onNext)
            }
            queueHandle(onQueue: onQueue, action: doAction)
        }
    }
    /// Simple step for logging.
    /// 記錄 Log 的簡單步驟
    public static func log(
        id: String? = nil,
        index: Int? = nil,
        _ items: Any...
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action(id: id, index: index) { actionStyle in
            print("SNLog: \(items)")
            actionStyle(.onNext)
        }
    }
    /// Delay for a certain duration before continuing.
    /// Allows specifying the queue and delay time in seconds.
    /// 延遲一定時間再繼續
    /// 可指定 Queue 與延遲秒數
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
                    actionStyle(.onNext)
                }
            case .global(let createStyle):
                DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                    actionStyle(.onNext)
                }
            case .custom(queue: let queue):
                queue.asyncAfter(deadline: .now() + seconds) {
                    actionStyle(.onNext)
                }
            case .none:
                actionStyle(.onNext)
            }
        }
    }
    /// async action
    /// 非同步執行
    public static func asyncAction(
        id: String? = nil,
        index: Int? = nil,
        onQueue: SNFlowControl.QueueStyle = .none,
        action: @escaping SNFlowControl.StepBlock
    ) -> SNFlowControl.AsyncAction{
        return SNFlowControl.AsyncAction(id: id, index: index, asyncAction: action, action: { actionStyle in
            let doAction = {
                // 給Builer使用繼續後面流程
                actionStyle(.onNext)
            }
            queueHandle(onQueue: onQueue, action: doAction)
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
