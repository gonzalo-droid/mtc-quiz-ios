// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCPremiumFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCPremiumFeature", targets: ["MTCPremiumFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
        .package(path: "../MTCDesignSystem"),
    ],
    targets: [
        .target(
            name: "MTCPremiumFeature",
            dependencies: ["MTCDomain", "MTCDesignSystem"]
        ),
        .testTarget(
            name: "MTCPremiumFeatureTests",
            dependencies: ["MTCPremiumFeature", "MTCDomain"]
        ),
    ]
)
