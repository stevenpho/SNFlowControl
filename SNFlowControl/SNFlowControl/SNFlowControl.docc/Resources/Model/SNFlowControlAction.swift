//
//  SNFlowControlAction.swift
//  
//
//  Created by Lee Steve on 2025/5/5.
//
import Foundation

extension SNFlowControl {
    typealias FinishedBlock = () -> Void
    typealias StepBlock = (@escaping(_ actionContext: ActionStyle) -> Void) -> Void
    typealias ThenBlock = () -> Void
    typealias IfBlock = () -> Bool
    public class Action {
        let action: StepBlock
        init(action: @escaping StepBlock) {
            self.action = action
        }
    }
    
    enum ActionStyle: Equatable {
        case onNext
        case onStop
        case onFinished
    }
    
    enum QueueStyle: Equatable {
        case main(createStyle: QueueCreateStyle)
        case global(createStyle: QueueCreateStyle)
        case none
    }
    
    enum QueueCreateStyle: Equatable {
        /// 建立新的async queue
        case new
        /// 沿用當前同個queue 如果不是目標的queue style會檢查來決定要不要建立新的queue
        case none
    }
}

// MARK: SNFlowControl Action Flow
extension SNFlowControl.Action {
    
    static func `if`(onQueue: SNFlowControl.QueueStyle = .none, condition: @escaping SNFlowControl.IfBlock) -> SNFlowControl.Action{
        return SNFlowControl.Action { actionStyle in
            switch condition() {
            case true:
                actionStyle(.onNext)
            case false:
                actionStyle(.onStop)
            }
        }
    }
    
    static func then(onQueue: SNFlowControl.QueueStyle = .none, action: @escaping SNFlowControl.ThenBlock) -> SNFlowControl.Action{
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
    
    static func log(_ items: Any...) -> SNFlowControl.Action{
        return SNFlowControl.Action { actionStyle in
            print("Log: \(items)")
            actionStyle(.onNext)
        }
    }
    
    static func delay(onQueue: SNFlowControl.QueueStyle, seconds: TimeInterval) -> SNFlowControl.Action{
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
