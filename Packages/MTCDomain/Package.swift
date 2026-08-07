// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MTCDomain",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MTCDomain", targets: ["MTCDomain"]),
    ],
    targets: [
        .target(name: "MTCDomain"),
        .testTarget(name: "MTCDomainTests", dependencies: ["MTCDomain"]),
    ]
)
