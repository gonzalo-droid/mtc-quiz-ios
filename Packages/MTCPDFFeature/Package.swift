// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCPDFFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCPDFFeature", targets: ["MTCPDFFeature"]),
    ],
    dependencies: [
        .package(path: "../MTCDomain"),
    ],
    targets: [
        .target(
            name: "MTCPDFFeature",
            dependencies: ["MTCDomain"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MTCPDFFeatureTests",
            dependencies: ["MTCPDFFeature", "MTCDomain"]
        ),
    ]
)
