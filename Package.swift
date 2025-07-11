// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Warring!! - swift-testing 추가 금지. swift 6에 이미 포함되어 있음.
let package = Package(
    name: "Dendrite",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "Dendrite",
            targets: ["Dendrite"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.1"),
    ],
    targets: [
        .target(
            name: "Dendrite",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ]
        ),
        .testTarget(
            name: "DendriteTests",
            dependencies: [
                "Dendrite",
            ],
            resources: [
                .process("Resources"),
            ]
        )
    ]
)
