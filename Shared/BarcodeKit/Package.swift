// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "BarcodeKit",
    platforms: [
        .iOS("18.6"),
    ],
    products: [
        .library(name: "BarcodeKit", targets: ["BarcodeKit"]),
    ],
    dependencies: [
        .package(name: "ScannerLogger", path: "../ScannerLogger"),
    ],
    targets: [
        .target(
            name: "BarcodeKit",
            dependencies: ["ScannerLogger"]
        ),
        .testTarget(
            name: "BarcodeKitTests",
            dependencies: ["BarcodeKit"]
        ),
    ]
)
