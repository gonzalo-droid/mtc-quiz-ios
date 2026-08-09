// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCQuestionReviewFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCQuestionReviewFeature", targets: ["MTCQuestionReviewFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
        .package(path: "../MTCDesignSystem"),
    ],
    targets: [
        .target(
            name: "MTCQuestionReviewFeature",
            dependencies: ["MTCDomain", "MTCDesignSystem"]
        ),
        .testTarget(
            name: "MTCQuestionReviewFeatureTests",
            dependencies: ["MTCQuestionReviewFeature", "MTCDomain"]
        ),
    ]
)
