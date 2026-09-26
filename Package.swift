// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "SuperKeys",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "super-keys", targets: ["SuperKeys"]),
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "SuperKeys",
            dependencies: [
                .product(name: "HotKey", package: "HotKey"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
    ]
)
