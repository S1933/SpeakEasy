// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Spike",
    platforms: [.iOS("26.0")],
    targets: [
        .executableTarget(
            name: "Spike",
            path: "Sources/Spike",
            resources: [.copy("Resources/sample.wav")]
        )
    ]
)
