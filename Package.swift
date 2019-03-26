// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "playground-simplified",
    platforms: [
        .macOS(.v10_14)
    ],
    products: [
        .executable(name: "MarkdownPlaygrounds", targets: ["MarkdownPlaygrounds"]),
    ],
    dependencies: [
        .package(url: "https://github.com/objcio/commonmark-swift", .branch("swift-5")),
        .package(url: "https://github.com/apple/swift-syntax.git", .exact("0.40200.0")),
    ],
    targets: [
        .target(
            name: "MarkdownPlaygrounds",
            dependencies: ["MarkdownPlaygroundsLibrary"]
        ),
        .target(
            name: "MarkdownPlaygroundsLibrary",
            dependencies: ["CommonMark", "Ccmark", "SwiftSyntax"]
        ),
        .testTarget(
            name: "MarkdownPlaygroundsTests",
            dependencies: ["MarkdownPlaygroundsLibrary"]
        ),
    ]
)
