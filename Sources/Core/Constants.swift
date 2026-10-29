import Foundation

/// Tunable numbers of the scan, in one place.
enum ScanConfig {
    /// ponytail: folders and files below 1 MB fold into one row per folder; keeps the tree small (memory, energy).
    /// Lower it if someone needs to see tiny files.
    static let keepBytes: Int64 = 1 << 20
    static let progressInterval: TimeInterval = 0.5
    static let cancelCheckMask = 0xFFF  // check cancellation and progress every 4096 entries
    static let deleteSettleDelay: Duration = .seconds(2)  // APFS reports freed blocks with a short delay
    static let searchDebounce: Duration = .milliseconds(250)
    static let searchLimit = 500
    static let iconCacheLimit = 2_000
    static let selfTestTolerance = 0.02
    static let maxEstimatedFraction = 0.99  // an estimate never claims "done" before the scan really is
}

/// What the cleaner may remove and how old things must be.
enum CleanConfig {
    static let tempMinAgeDays = 3
    static let logMinAgeDays = 7
    static let unusedDayOptions = [30, 90, 180, 365]
    static let defaultUnusedDays = 90
}

enum LargeFileThreshold {
    static let optionsMB = [10, 50, 100, 250, 500, 1000, 5000]
    static let defaultMB = 500
    static func bytes(_ mb: Int) -> Int64 { Int64(mb) * 1_000_000 }
}

/// Hidden stand-in text that keeps the space of a value still being calculated; it is never shown or read.
enum StandInText {
    static let figure = "0.000.000"
}

enum WindowID {
    static let main = "main"
}

enum SystemLinks {
    static let fullDiskAccess = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
}
