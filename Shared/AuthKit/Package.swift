// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "AuthKit",
    platforms: [
        .iOS("18.6"),
    ],
    products: [
        .library(name: "AuthKit", targets: ["AuthKit"]),
    ],
    dependencies: [
        .package(name: "ScannerSecrets", path: "../ScannerSecrets"),
        .package(name: "ScannerLogger", path: "../ScannerLogger"),
    ],
    targets: [
        .target(
            name: "AuthKit",
            dependencies: ["ScannerSecrets", "ScannerLogger"]
        ),
        .testTarget(
            name: "AuthKitTests",
            dependencies: ["AuthKit"]
        ),
    ]
)
