import Foundation

/// Tunable numbers of the scan, in one place.
nonisolated enum ScanLimits {
    /// ponytail: folders and files below 1 MB fold into one row per folder; keeps the tree small
    /// (memory, energy). Lower it if someone needs to see tiny files.
    static let smallestListedBytes: Int64 = 1 << 20
    static let progressInterval: TimeInterval = 0.5
    static let cancelCheckMask = 0xFFF  // check cancellation and progress every 4096 entries
    static let searchDebounce: Duration = .milliseconds(250)
    static let maximumSearchResults = 500
    static let maximumCachedImages = 2_000
}

/// A volume runs low below this share of its capacity, but never above the fixed amount: on a big
/// disk a tenth is still plenty.
nonisolated enum LowSpace {
    static let warningShare = 0.1
    static let largestWarningBytes: Int64 = 25_000_000_000
}

/// What the cleaner may remove and how old things must be.
nonisolated enum CleanUpRules {
    static let temporaryMinimumAgeDays = 3
    static let logMinimumAgeDays = 7
    static let installerMinimumAgeDays = 30
    static let unusedDayOptions = [30, 90, 180, 365]
    static let defaultUnusedDays = 90
}

enum LargeFileThreshold {
    static let megabyteOptions = [10, 50, 100, 250, 500, 1000, 5000]
    static let defaultMegabytes = 500
    private static let bytesPerMegabyte: Int64 = 1_000_000

    static func bytes(_ megabytes: Int) -> Int64 { Int64(megabytes) * bytesPerMegabyte }
}

/// Hidden stand-in text that keeps the space of a value still being calculated; it is never shown
/// or read.
enum StandInText {
    static let figure = "0.000.000"
}

enum WindowID {
    static let main = "main"
}

enum SystemLinks {
    static let fullDiskAccess: URL = {
        let address = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        guard let link = URL(string: address) else { preconditionFailure("invalid settings link") }
        return link
    }()
}
