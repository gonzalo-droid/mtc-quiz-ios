// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCAdsFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCAdsFeature", targets: ["MTCAdsFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "12.0.0"),
    ],
    targets: [
        .target(
            name: "MTCAdsFeature",
            dependencies: [
                "MTCDomain",
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
            ]
        ),
        .testTarget(
            name: "MTCAdsFeatureTests",
            dependencies: ["MTCAdsFeature"]
        ),
    ]
)
