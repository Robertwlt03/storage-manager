// swift-tools-version:6.4
import PackageDescription

// Code runs on the main actor unless it says otherwise, so only the work that really runs in the
// background (scanning, measuring) is marked as such. With Swift 6.2's approachable concurrency an
// async function without an actor runs where its caller runs, unless it says @concurrent.
let mainActorByDefault: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

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
