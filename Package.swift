// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MenuDeck",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "MenuDeck",
            path: "Sources/MenuDeck",
            exclude: ["Assets/AppIcon.icns"],
            resources: [.copy("Assets/AppIcon.png")]
        )
    ]
)
