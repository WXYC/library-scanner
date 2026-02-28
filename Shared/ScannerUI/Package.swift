// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "ScannerUI",
    platforms: [
        .iOS("18.6"),
    ],
    products: [
        .library(name: "ScannerUI", targets: ["ScannerUI"]),
    ],
    dependencies: [
        .package(name: "ScannerKit", path: "../ScannerKit"),
        .package(name: "CatalogClient", path: "../CatalogClient"),
    ],
    targets: [
        .target(
            name: "ScannerUI",
            dependencies: ["ScannerKit", "CatalogClient"]
        ),
        .testTarget(
            name: "ScannerUITests",
            dependencies: ["ScannerUI"]
        ),
    ]
)
