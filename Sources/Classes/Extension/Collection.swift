//
//  Collection.swift
//  
//
//  Created by Lee Steve on 2025/5/5.
//
import Foundation
extension Collection {
    public subscript(safe index: Index) -> Iterator.Element? {
        return (startIndex <= index && index < endIndex) ? self[index] : nil
    }
}
