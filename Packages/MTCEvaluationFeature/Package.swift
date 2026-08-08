// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCEvaluationFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCEvaluationFeature", targets: ["MTCEvaluationFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
        .package(path: "../MTCDesignSystem"),
    ],
    targets: [
        .target(
            name: "MTCEvaluationFeature",
            dependencies: ["MTCDomain"]
        ),
        .testTarget(
            name: "MTCEvaluationFeatureTests",
            dependencies: ["MTCEvaluationFeature", "MTCDomain"]
        ),
    ]
)
