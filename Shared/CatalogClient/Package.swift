// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "CatalogClient",
    platforms: [
        .iOS("18.6"),
    ],
    products: [
        .library(name: "CatalogClient", targets: ["CatalogClient"]),
    ],
    dependencies: [
        .package(name: "AuthKit", path: "../AuthKit"),
        .package(name: "ScannerLogger", path: "../ScannerLogger"),
    ],
    targets: [
        .target(
            name: "CatalogClient",
            dependencies: ["AuthKit", "ScannerLogger"]
        ),
        .testTarget(
            name: "CatalogClientTests",
            dependencies: ["CatalogClient"]
        ),
    ]
)
