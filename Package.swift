// swift-tools-version:6.4
import PackageDescription

// Swift 6 checks data races at compile time. Code runs on the main actor unless it says otherwise,
// so only the work that really runs in the background (scanning, measuring) is marked as such.
let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "SpeicherExplorer",
    platforms: [.macOS(.v27)],
    targets: [
        .executableTarget(
            name: "SpeicherExplorer", path: "Sources", swiftSettings: mainActorByDefault),
        .testTarget(
            name: "SpeicherExplorerTests", dependencies: ["SpeicherExplorer"],
            path: "Tests/SpeicherExplorerTests", swiftSettings: mainActorByDefault),
    ],
    swiftLanguageModes: [.v6]
)
