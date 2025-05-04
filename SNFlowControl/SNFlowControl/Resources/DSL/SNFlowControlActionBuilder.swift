//
//  SNFlowControlActionBuilder.swift
//  
//
//  Created by Lee Steve on 2025/5/5.
//
import Foundation

@resultBuilder
struct SNFlowControlActionBuilder {
    static func buildBlock(_ actions: SNFlowControl.Action...) -> [SNFlowControl.Action] {
        return actions
    }
    
    static func buildPartialBlock(first: SNFlowControl.Action) -> SNFlowControl.Action {
        first
    }
    
    static func buildOptional(_ component: SNFlowControl.Action?) -> SNFlowControl.Action {
        component ?? .then {}
    }
    
    static func buildEither(first component: SNFlowControl.Action) -> SNFlowControl.Action {
        component
    }
    
    static func buildEither(second component: SNFlowControl.Action) -> SNFlowControl.Action {
        component
    }
    
    static func buildExpression(_ expression: SNFlowControl.Action) -> SNFlowControl.Action {
        expression
    }
    
    
    static func buildArray(_ components: [SNFlowControl.Action]) -> [SNFlowControl.Action] {
        components
    }
    
    static func buildLimitedAvailability(_ component: SNFlowControl.Action) -> SNFlowControl.Action {
        component
    }
}
