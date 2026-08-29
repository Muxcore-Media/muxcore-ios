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
                "Models/ExtendedModels.swift",
                "Utilities/AuthCallback.swift",
                "Utilities/ServerURL.swift",
                "Utilities/JSONHelpers.swift",
                "Utilities/PosterURL.swift",
                "Utilities/MediaNormalizer.swift",
                "Utilities/IntExtensions.swift",
                "Utilities/WebVTTParser.swift",
            ]
        ),
        .testTarget(
            name: "MuxCoreKitTests",
            dependencies: ["MuxCoreKit"],
            path: "Tests"
        ),
    ]
)
