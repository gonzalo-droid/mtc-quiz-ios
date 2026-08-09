// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCSettingsFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCSettingsFeature", targets: ["MTCSettingsFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
        .package(path: "../MTCDesignSystem"),
    ],
    targets: [
        .target(
            name: "MTCSettingsFeature",
            dependencies: ["MTCDomain"]
        ),
        .testTarget(
            name: "MTCSettingsFeatureTests",
            dependencies: ["MTCSettingsFeature", "MTCDomain"]
        ),
    ]
)
