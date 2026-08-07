// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCDesignSystem",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCDesignSystem", targets: ["MTCDesignSystem"]),
    ],
    targets: [
        .target(name: "MTCDesignSystem"),
    ]
)
