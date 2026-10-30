// swift-format-ignore-file
import Foundation

enum DiskSamples {
    static func listFolder(_ folder: String) -> [String] {
        let manager = FileManager.default
        let names = try? manager.contentsOfDirectory(atPath: folder)  // expect: on the main thread
        return names ?? []
    }

    /// The same call in an @concurrent function runs off the main thread, so it counts as fine.
    @concurrent
    static func readFolder(_ folder: String) async -> [String] {
        let names = try? FileManager.default.contentsOfDirectory(atPath: folder)
        return names ?? []
    }
}

/// The same call, free of the main thread, counts as fine.
nonisolated enum QuietDiskSamples {
    static func listFolder(_ folder: String) -> [String] {
        let names = try? FileManager.default.contentsOfDirectory(atPath: folder)
        return names ?? []
    }
}
