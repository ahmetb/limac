// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Limac",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Limac",
            path: "Sources/Limac",
            // The HTML preview stays in the repo but out of the app bundle.
            exclude: ["Resources/lime-assets.html"],
            resources: [
                .copy("Resources/lime-full.svg"),
                .copy("Resources/lime-empty.svg"),
                .copy("Resources/lime-animated.svg")
            ]
        )
    ]
)
