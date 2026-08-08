// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCData",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCData", targets: ["MTCData"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
    ],
    targets: [
        .target(
            name: "MTCData",
            dependencies: ["MTCDomain"],
            resources: [
                .process("Resources/categories.json"),
                .copy("Resources/Questions"),
                .copy("Resources/Images"),
            ]
        ),
        .testTarget(name: "MTCDataTests", dependencies: ["MTCData", "MTCDomain"]),
    ]
)
