// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "ScannerKit",
    platforms: [
        .iOS("18.6"),
    ],
    products: [
        .library(name: "ScannerKit", targets: ["ScannerKit"]),
    ],
    dependencies: [
        .package(name: "CatalogClient", path: "../CatalogClient"),
        .package(name: "CameraKit", path: "../CameraKit"),
        .package(name: "BarcodeKit", path: "../BarcodeKit"),
        .package(name: "ScannerLogger", path: "../ScannerLogger"),
    ],
    targets: [
        .target(
            name: "ScannerKit",
            dependencies: ["CatalogClient", "CameraKit", "BarcodeKit", "ScannerLogger"]
        ),
        .testTarget(
            name: "ScannerKitTests",
            dependencies: ["ScannerKit"]
        ),
    ]
)
