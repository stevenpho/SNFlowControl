//
//  SNFlowControlCoreTest.swift
//  SNFlowControl
//
//  Created by Lee Steve on 2026/5/1.
//
import XCTest
@testable import SNFlowControl

final class SNFlowControlTests: XCTestCase {
    /// Test Sync Flow
    func testSyncFlow() {
        var result = 0
        SNFlowControl(
            builderActios: {
                SNFlowControl.Action { context in
                    result += 1
                    context(.onNext(nil))
                }
                
                SNFlowControl.Action { context in
                    result += 1
                    context(.onNext(nil))
                }
                
                SNFlowControl.Action { context in
                    result += 1
                    context(.onNext(nil))
                }
            },
            finished: { finishByStyle in
                XCTAssertTrue(result == 3)
            }
        ).start()
    }
    /// Test Sync with Delay Flow
    func testSyncDelayFlow() {
        var result = 0
        SNFlowControl(
            builderActios: {
                SNFlowControl.Action { context in
                    result += 1
                    context(.onNext(nil))
                }
                
                SNFlowControl.Action { context in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                        result += 1
                        context(.onNext(nil))
                    }
                }
                
                SNFlowControl.Action { context in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                        result += 1
                        context(.onNext(nil))
                    }
                }
                
                SNFlowControl.Action { context in
                    result += 1
                    context(.onNext(nil))
                }
            },
            finished: { finishByStyle in
                XCTAssertTrue(result == 4)
            }
        ).start()
    }
    /// Test ASync Flow
    func testAsyncFlow() {
        var result = 0
        SNFlowControl(
            builderActios: {
                SNFlowControl.AsyncAction { context in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                        result += 1
                        context(.onNext(nil))
                    }
                }
                
                SNFlowControl.Action { context in
                    result += 1
                    context(.onNext(nil))
                }
                
                SNFlowControl.Action { context in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                        result += 1
                        context(.onNext(nil))
                    }
                }
                
                SNFlowControl.AsyncAction { context in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                        result += 1
                        context(.onNext(nil))
                    }
                }
                
                SNFlowControl.Action { context in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                        result += 1
                        context(.onNext(nil))
                    }
                }
                
                SNFlowControl.Action { context in
                    result += 1
                    context(.onNext(nil))
                }
            },
            finished: { finishByStyle in
                XCTAssertTrue(result == 6)
            }
        ).start()
    }
}
