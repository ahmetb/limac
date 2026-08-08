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
            path: "Sources/Limac"
        )
    ]
)
