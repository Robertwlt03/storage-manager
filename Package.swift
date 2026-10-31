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
    name: "StorageManager",
    platforms: [.macOS(.v27)],
    targets: [
        .executableTarget(
            name: "StorageManager", path: "Sources", swiftSettings: mainActorByDefault),
        // The widget extension; build.py puts it into the app as PlugIns/StorageWidget.appex.
        .executableTarget(
            name: "StorageWidget", path: "Widget", exclude: ["Info.plist", "Widget.entitlements"],
            swiftSettings: mainActorByDefault),
        .testTarget(
            name: "StorageManagerTests", dependencies: ["StorageManager", "StorageWidget"],
            path: "Tests/StorageManagerTests", swiftSettings: mainActorByDefault),
    ],
    swiftLanguageModes: [.v6]
)
