// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Clutch",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Clutch",
            path: "Sources/Clutch",
            exclude: ["Assets/AppIcon.icns"],
            resources: [.copy("Assets/AppIcon.png")]
        )
    ]
)
