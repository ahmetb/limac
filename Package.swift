// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Limac",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0")
    ],
    targets: [
        .executableTarget(
            name: "Limac",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Limac",
            // The HTML preview stays in the repo but out of the app bundle.
            exclude: ["Resources/lime-assets.html"],
            resources: [
                .copy("Resources/lime-full.svg"),
                .copy("Resources/lime-empty.svg"),
                .copy("Resources/lime-animated.svg")
            ],
            linkerSettings: [
                // Finds Sparkle at Contents/Frameworks inside Limac.app.
                // Under `swift run` this rpath resolves to nothing and the
                // SwiftPM-added @loader_path rpath finds the framework
                // sitting next to the bare executable instead.
                .unsafeFlags(["-Xlinker", "-rpath",
                              "-Xlinker", "@executable_path/../Frameworks"])
            ]
        )
    ]
)
