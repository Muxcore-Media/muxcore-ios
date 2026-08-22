// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MuxCoreKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "MuxCoreKit", targets: ["MuxCoreKit"]),
    ],
    targets: [
        .target(
            name: "MuxCoreKit",
            path: "Sources",
            sources: [
                "Models/MediaModels.swift",
                "Utilities/JSONHelpers.swift",
                "Utilities/PosterURL.swift",
                "Utilities/MediaNormalizer.swift",
                "Utilities/IntExtensions.swift",
            ]
        ),
        .testTarget(
            name: "MuxCoreKitTests",
            dependencies: ["MuxCoreKit"],
            path: "Tests"
        ),
    ]
)
