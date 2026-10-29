// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SpeicherExplorer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "SpeicherExplorer", path: "Sources"),
        .testTarget(
            name: "SpeicherExplorerTests", dependencies: ["SpeicherExplorer"],
            path: "Tests/SpeicherExplorerTests"),
    ]
)
