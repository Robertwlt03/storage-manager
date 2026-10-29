import Foundation

/// Small questions about files and dates that several services ask.
nonisolated enum FileSystem {
    private static let secondsPerDay: TimeInterval = 86_400

    /// The names inside a folder; a folder that cannot be read counts as empty.
    static func names(in folder: String) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
    }

    /// The moment `days` whole days before `date`.
    static func date(daysBefore days: Int, _ date: Date = Date()) -> Date {
        date.addingTimeInterval(-Double(days) * secondsPerDay)
    }
}
