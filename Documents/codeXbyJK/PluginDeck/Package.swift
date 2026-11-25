// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PluginDeck",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginDeckCore", targets: ["PluginDeckCore"]),
        .executable(name: "PluginDeck", targets: ["PluginDeckApp"]),
    ],
    targets: [
        .target(name: "PluginDeckCore"),
        .executableTarget(name: "PluginDeckApp", dependencies: ["PluginDeckCore"]),
        .testTarget(name: "PluginDeckCoreTests", dependencies: ["PluginDeckCore"]),
    ]
)
