// swift-tools-version: 6.4
// Samples with a mistake for every rule, so the checks can test themselves (see samples.py).
import PackageDescription

let package = Package(
    name: "Samples",
    platforms: [.macOS(.v27)],
    targets: [.executableTarget(name: "Samples", path: "Sources")]
)
