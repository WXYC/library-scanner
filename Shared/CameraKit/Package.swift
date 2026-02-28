// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "CameraKit",
    platforms: [
        .iOS("18.6"),
    ],
    products: [
        .library(name: "CameraKit", targets: ["CameraKit"]),
    ],
    dependencies: [
        .package(name: "ScannerLogger", path: "../ScannerLogger"),
    ],
    targets: [
        .target(
            name: "CameraKit",
            dependencies: ["ScannerLogger"]
        ),
        .testTarget(
            name: "CameraKitTests",
            dependencies: ["CameraKit"]
        ),
    ]
)
