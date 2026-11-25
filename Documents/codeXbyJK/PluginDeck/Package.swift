// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PluginDeck",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginDeckCore", targets: ["PluginDeckCore"]),
        .library(name: "PluginDeckSkin", targets: ["PluginDeckSkin"]),
        .executable(name: "PluginDeck", targets: ["PluginDeckApp"]),
    ],
    targets: [
        .target(name: "PluginDeckCore"),
        // 레트로 스킨: 색/글꼴 토큰 + 화면 부품. 앱 상태(LibraryModel)를 모르고 값만 받는다 -> 테스트에서 이미지로 렌더링 가능
        .target(name: "PluginDeckSkin", dependencies: ["PluginDeckCore"]),
        .executableTarget(name: "PluginDeckApp", dependencies: ["PluginDeckCore", "PluginDeckSkin"]),
        .testTarget(name: "PluginDeckCoreTests", dependencies: ["PluginDeckCore", "PluginDeckSkin"]),
    ]
)
