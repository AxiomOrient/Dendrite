// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Dendrite",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "Dendrite",
            targets: ["Dendrite"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Dendrite",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .testTarget(
            name: "DendriteTests",
            dependencies: ["Dendrite"],
            resources: [
                .copy("Resources"),
            ]
        )
    ]
)
