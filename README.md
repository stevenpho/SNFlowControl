# SNFlowControl

[![Platform](https://img.shields.io/cocoapods/p/SNFlowControl.svg)](https://cocoapods.org/pods/SNFlowControl)
[![Version](https://img.shields.io/cocoapods/v/SNFlowControl.svg)](https://cocoapods.org/pods/SNFlowControl)
[![License](https://img.shields.io/cocoapods/l/SNFlowControl.svg)](https://cocoapods.org/pods/SNFlowControl)
[![Swift](https://img.shields.io/badge/swift-5.0-orange.svg)](https://swift.org)

> A lightweight, SwiftUI-style builder for chaining synchronous and asynchronous flow control steps in Swift.

---

## ✨ Features

- DSL-style syntax like SwiftUI
- Chain multiple actions in sequence
- Supports both synchronous and asynchronous tasks
- Conditional branching (`if`)
- Built-in delay, log, and queue support
- Optional completion callback
- Clean and extensible design

---

## 📦 Installation

### CocoaPods

```ruby
pod 'SNFlowControl'

在你的 Podfile 中加入上述內容。

執行 pod install。

在需要的地方 import SNFlowControl。

🚀 Usage

import SNFlowControl

func example1() {
    SNFlowControl {
        SNAction { context in
            print("step1")
            context(.onNext)
        }
        
        SNAction.log("record")
        
        SNAction.then(onQueue: .none) {
            print("do stuff")
        }
        
        SNAction.delay(onQueue: .main(createStyle: .none), seconds: 3)
        
        SNAction.log("after delay 3 seconds")
        
        SNAction.if {
            return true
        }
        
        SNAction { context in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                context(.onNext)
            }
        }
        
        SNAction.log("wait until async action finished")
        
    } finished: {
        print("flow control end")
    }.start()
}
🛠 Supported Platforms
iOS 11.0+

macOS 10.13+

Swift 5.0+

📄 License
MIT License. See LICENSE for details.

💡 Inspiration
Inspired by functional reactive programming and SwiftUI DSL.
