// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCOnboardingFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCOnboardingFeature", targets: ["MTCOnboardingFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDesignSystem"),
    ],
    targets: [
        .target(
            name: "MTCOnboardingFeature",
            dependencies: ["MTCDesignSystem"]
        ),
    ]
)
