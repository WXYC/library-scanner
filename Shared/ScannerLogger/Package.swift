// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "ScannerLogger",
    platforms: [
        .iOS("18.6"),
    ],
    products: [
        .library(name: "ScannerLogger", targets: ["ScannerLogger"]),
    ],
    targets: [
        .target(
            name: "ScannerLogger",
            linkerSettings: [
                .linkedFramework("Foundation"),
            ]
        ),
        .testTarget(
            name: "ScannerLoggerTests",
            dependencies: ["ScannerLogger"]
        ),
    ]
)
