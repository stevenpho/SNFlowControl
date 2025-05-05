//
//  SNFlowControlAction.swift
//  
//
//  Created by Lee Steve on 2025/5/5.
//
import Foundation

extension SNFlowControl {
    /// Called when the flow completes.
    /// 流程結束時的回呼
    public typealias FinishedBlock = () -> Void
    /// Core step execution block. You must call context(.onNext / .onStop / .onFinished)
    /// 執行核心邏輯的區塊，必須呼叫 context 來控制流程是否繼續或終止
    public typealias StepBlock = (@escaping(_ actionContext: ActionStyle) -> Void) -> Void
    /// A simplified step without flow control callback.
    /// 簡單的步驟邏輯，不需要手動控制流程
    public typealias ThenBlock = () -> Void
    /// Condition block returning Bool
    /// 判斷條件用區塊
    public typealias IfBlock = () -> Bool
    /// Represents a single step in the flow.
    /// 表示流程中的單一步驟
    public class Action {
        let action: StepBlock
        public init(action: @escaping StepBlock) {
            self.action = action
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
        ///  No queue switching / 不切換 Queue
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
    /// 條件判斷區塊
    /// - 如果為 true 則繼續下一步，false 則中斷流程
    public static func `if`(onQueue: SNFlowControl.QueueStyle = .none, condition: @escaping SNFlowControl.IfBlock) -> SNFlowControl.Action{
        return SNFlowControl.Action { actionStyle in
            switch condition() {
            case true:
                actionStyle(.onNext)
            case false:
                actionStyle(.onStop)
            }
        }
    }
    /// 簡單步驟，不帶流程控制
    /// 可指定執行緒與建立方式
    public static func then(onQueue: SNFlowControl.QueueStyle = .none, action: @escaping SNFlowControl.ThenBlock) -> SNFlowControl.Action{
        return SNFlowControl.Action { actionStyle in
            let doAction = {
                action()
                actionStyle(.onNext)
            }
            switch onQueue {
            case .main(let createStyle):
                let doMainAction = {
                    DispatchQueue.main.async {
                        doAction()
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
                    doAction()
                }
            case .global(let createStyle):
                let doGlobalAction = {
                    DispatchQueue.global().async {
                        doAction()
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
                    doAction()
                }
            case .none:
                doAction()
            }
        }
    }
    /// 記錄 Log 的簡單步驟
    public static func log(_ items: Any...) -> SNFlowControl.Action{
        return SNFlowControl.Action { actionStyle in
            print("SNLog: \(items)")
            actionStyle(.onNext)
        }
    }
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
