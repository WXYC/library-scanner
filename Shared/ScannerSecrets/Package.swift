// swift-tools-version:6.2

import PackageDescription
import Foundation

let package = Package(
    name: "ScannerSecrets",
    platforms: [
        .iOS("18.6"),
    ],
    products: [
        .library(name: "ScannerSecrets", targets: ["ScannerSecrets"]),
    ],
    dependencies: [
        .package(url: "https://github.com/p-x9/ObfuscateMacro.git", .upToNextMajor(from: "0.10.0")),
    ],
    targets: [
        .target(
            name: "ScannerSecrets",
            dependencies: [
                .product(name: "ObfuscateMacro", package: "ObfuscateMacro"),
            ]
        ),
    ]
)
