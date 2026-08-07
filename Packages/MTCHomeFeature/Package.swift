// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCHomeFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCHomeFeature", targets: ["MTCHomeFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
        .package(path: "../MTCDesignSystem"),
    ],
    targets: [
        .target(
            name: "MTCHomeFeature",
            dependencies: ["MTCDomain"]
        ),
        .testTarget(
            name: "MTCHomeFeatureTests",
            dependencies: ["MTCHomeFeature", "MTCDomain"]
        ),
    ]
)
