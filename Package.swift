// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "SuperKeys",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "super-keys", targets: ["SuperKeys"]),
        .library(name: "SuperKeysCore", targets: ["SuperKeysCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1"),
        .package(url: "https://github.com/dduan/TOMLDecoder", from: "0.4.4"),
    ],
    targets: [
        .target(
            name: "SuperKeysCore",
            dependencies: [
                .product(name: "TOMLDecoder", package: "TOMLDecoder"),
            ]
        ),
        .executableTarget(
            name: "SuperKeys",
            dependencies: [
                "SuperKeysCore",
                .product(name: "HotKey", package: "HotKey"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "SuperKeysCoreTests",
            dependencies: ["SuperKeysCore"]
        ),
    ]
)
