// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "playground-simplified",
    platforms: [
        .macOS(.v10_14)
    ],
    dependencies: [
        .package(url: "https://github.com/objcio/commonmark-swift", .branch("swift-5")),
        .package(url: "https://github.com/apple/swift-syntax.git", .exact("0.40200.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "playground-simplified",
            dependencies: ["CommonMark", "Ccmark", "SwiftSyntax"]),
        .testTarget(
            name: "playground-simplifiedTests",
            dependencies: ["playground-simplified"]),
    ]
)
