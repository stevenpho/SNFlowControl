//
//  SNFlowControlActionBuilder.swift
//  
//
//  Created by Lee Steve on 2025/5/5.
//
import Foundation

@resultBuilder
public struct SNFlowControlActionBuilder {
    public static func buildBlock(_ actions: SNFlowControl.Action...) -> [SNFlowControl.Action] {
        return actions
    }
    
    public static func buildPartialBlock(first: SNFlowControl.Action) -> SNFlowControl.Action {
        first
    }
    
    public static func buildOptional(_ component: SNFlowControl.Action?) -> SNFlowControl.Action {
        component ?? .then {}
    }
    
    public static func buildEither(first component: SNFlowControl.Action) -> SNFlowControl.Action {
        component
    }
    
    public static func buildEither(second component: SNFlowControl.Action) -> SNFlowControl.Action {
        component
    }
    
    public static func buildExpression(_ expression: SNFlowControl.Action) -> SNFlowControl.Action {
        expression
    }
    
    
    public static func buildArray(_ components: [SNFlowControl.Action]) -> [SNFlowControl.Action] {
        components
    }
    
    public static func buildLimitedAvailability(_ component: SNFlowControl.Action) -> SNFlowControl.Action {
        component
    }
}
