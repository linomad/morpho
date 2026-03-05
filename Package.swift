// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Morpho",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "MorphoKit",
            targets: ["MorphoKit"]
        ),
        .executable(
            name: "MorphoApp",
            targets: ["MorphoApp"]
        ),
    ],
    targets: [
        .target(
            name: "MorphoKit"
        ),
        .executableTarget(
            name: "MorphoApp",
            dependencies: ["MorphoKit"]
        ),
        .testTarget(
            name: "MorphoKitTests",
            dependencies: ["MorphoKit"]
        ),
        .testTarget(
            name: "MorphoAppTests",
            dependencies: ["MorphoApp"]
        ),
    ]
)
