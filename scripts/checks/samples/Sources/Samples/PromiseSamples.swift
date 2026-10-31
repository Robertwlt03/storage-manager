// swift-format-ignore-file
import Foundation

nonisolated func removeQuietly(_ file: URL) throws {
    try FileManager.default.removeItem(at: file)  // expect: removes files outside the services
}

func goOnline() {
    _ = URLSession.shared  // expect: goes online
}
