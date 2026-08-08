// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCDetailFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCDetailFeature", targets: ["MTCDetailFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
        .package(path: "../MTCDesignSystem"),
    ],
    targets: [
        .target(
            name: "MTCDetailFeature",
            dependencies: ["MTCDomain", "MTCDesignSystem"]
        ),
        .testTarget(
            name: "MTCDetailFeatureTests",
            dependencies: ["MTCDetailFeature", "MTCDomain"]
        ),
    ]
)
