//
//  SNFlowControl.swift
//  
//
//  Created by Lee Steve on 2025/5/5.
//
import Foundation

public class SNFlowControl {
    let actios: [Action]
    let finished: FinishedBlock?
    var index = 0
    
    public init(actios: [Action], finished: FinishedBlock? = nil) {
        self.actios = actios
        self.finished = finished
    }
    
    public init(@SNFlowControlActionBuilder builderActios: () -> [Action], finished: FinishedBlock? = nil) {
        self.actios = builderActios()
        self.finished = finished
    }
    
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
