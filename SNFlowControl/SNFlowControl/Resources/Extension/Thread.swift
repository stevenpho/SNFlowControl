//
//  Thread.swift
//  
//
//  Created by Lee Steve on 2025/5/5.
//
import Foundation
extension Thread {
    class var isGlobalThread: Bool {
        return !Thread.isMainThread
    }
}
