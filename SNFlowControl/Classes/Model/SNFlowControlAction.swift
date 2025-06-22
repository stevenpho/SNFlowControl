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
    public typealias FinishedBlock = () -> Void
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
    typealias SwitchThenBlock<T: CaseIterable> = (T) -> Void
    /// Uses a closure to evaluate a condition, returns an enum to indicate the result,
    /// and lets you manually control the flow based on that result.
    /// 判斷條件用區塊 回傳enum 狀態 並手動控制流程
    typealias SwitchActionBlock<T: CaseIterable> = (T, @escaping ActionContextBlock) -> Void
    /// Represents a single step in the flow.
    /// 表示流程中的單一步驟
    public class Action {
        public let action: StepBlock
        public init(action: @escaping StepBlock) {
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
    static func switchThen<T: CaseIterable>(onQueue: SNFlowChain.QueueStyle = .none, state: T, stateAction: @escaping SNFlowChain.SwitchThenBlock<T>) -> SNFlowChain.Action{
        return SNFlowChain.Action { actionStyle in
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
    static func switchAction<T: CaseIterable>(onQueue: SNFlowChain.QueueStyle = .none, state: T, stateAction: @escaping SNFlowChain.SwitchActionBlock<T>) -> SNFlowChain.Action{
        return SNFlowChain.Action { actionStyle in
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
    static func ifNext(onQueue: SNFlowChain.QueueStyle = .none, condition: @escaping SNFlowChain.IfBlock) -> SNFlowChain.Action{
        return SNFlowChain.Action { actionStyle in
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
    public static func ifStop(onQueue: SNFlowControl.QueueStyle = .none, condition: @escaping SNFlowControl.IfBlock) -> SNFlowControl.Action{
        return SNFlowControl.Action { actionStyle in
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
    static func ifThen(onQueue: SNFlowControl.QueueStyle = .none, condition: @escaping SNFlowControl.IfBlock, action: @escaping SNFlowControl.ThenBlock) -> SNFlowControl.Action{
        return SNFlowControl.Action { actionStyle in
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
    static func ifElseThen(
        onQueue: SNFlowControl.QueueStyle = .none,
        condition: @escaping SNFlowControl.IfBlock,
        ifAction: @escaping SNFlowControl.ThenBlock,
        elseAction: @escaping SNFlowControl.ThenBlock
    ) -> SNFlowControl.Action{
        return SNFlowControl.Action { actionStyle in
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
    public static func then(onQueue: SNFlowControl.QueueStyle = .none, action: @escaping SNFlowControl.ThenBlock) -> SNFlowControl.Action{
        return SNFlowControl.Action { actionStyle in
            let doAction = {
                action()
                actionStyle(.onNext)
            }
            queueHandle(onQueue: onQueue, action: doAction)
        }
    }
    /// Simple step for logging.
    /// 記錄 Log 的簡單步驟
    public static func log(_ items: Any...) -> SNFlowControl.Action{
        return SNFlowControl.Action { actionStyle in
            print("SNLog: \(items)")
            actionStyle(.onNext)
        }
    }
    /// Delay for a certain duration before continuing.
    /// Allows specifying the queue and delay time in seconds.
    /// 延遲一定時間再繼續
    /// 可指定 Queue 與延遲秒數
    public static func delay(onQueue: SNFlowControl.QueueStyle, seconds: TimeInterval) -> SNFlowControl.Action{
        return SNFlowControl.Action { actionStyle in
            switch onQueue {
            case .main(let createStyle):
                DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                    actionStyle(.onNext)
                }
            case .global(let createStyle):
                DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                    actionStyle(.onNext)
                }
            case .none:
                actionStyle(.onNext)
            }
        }
    }
}
// MARK: Private - Method
extension SNFlowControl.Action {
    private static func queueHandle(onQueue: SNFlowControl.QueueStyle, action: @escaping SNFlowControl.FinishedBlock) {
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
        case .none:
            action()
        }
    }

}
