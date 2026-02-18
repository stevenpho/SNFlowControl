// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SNFlowControl",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "SNFlowControl",
            targets: ["SNFlowControl"]
        ),
    ],
    targets: [
        .target(
            name: "SNFlowControl",
            path: "Sources",
            sources: ["Classes"],
            resources: [
                //.process("Assets")
                .copy("Assets/PrivacyInfo.xcprivacy")
            ]
        )/*,
        .testTarget(
            name: "SNFlowControlTests",
            dependencies: ["SNFlowControl"]
        ),*/
    ]
)


