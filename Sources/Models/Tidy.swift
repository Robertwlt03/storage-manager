import Foundation

/// What the cleaner can remove; each kind regenerates by itself or is already thrown away.
nonisolated enum CleanKind: String, CaseIterable, Identifiable {
    case caches, developer, logs, temp, trash
    var id: Self { self }

    var title: TextKey {
        switch self {
        case .caches: .cleanCaches
        case .developer: .cleanDeveloper
        case .logs: .cleanLogs
        case .temp: .cleanTemp
        case .trash: .cleanTrash
        }
    }

    var detail: TextKey {
        switch self {
        case .caches: .cleanCachesDetail
        case .developer: .cleanDeveloperDetail
        case .logs: .cleanLogsDetail
        case .temp: .cleanTempDetail
        case .trash: .cleanTrashDetail
        }
    }

    /// Same symbol and colour as the matching storage category.
    var category: CategoryKind {
        switch self {
        case .caches: .caches
        case .developer: .developer
        case .logs: .library
        case .temp: .temp
        case .trash: .trash
        }
    }

    /// Selected by default; emptying the Trash stays a deliberate choice.
    var isPreselected: Bool { self != .trash }
}

nonisolated struct CleanItem: Identifiable {
    let kind: CleanKind
    let paths: [String]
    let bytes: Int64
    var id: CleanKind { kind }
}

struct AppUsage: Identifiable {
    let path: String
    let name: String
    let bundleID: String?
    let lastUsed: Date?
    let bytes: Int64
    var id: String { path }
}

enum SizeBucket: CaseIterable, Identifiable {
    case under1MB, to10MB, to100MB, to1GB, over1GB
    var id: Self { self }

    private static let tenMegabytes: Int64 = 10_000_000
    private static let hundredMegabytes: Int64 = 100_000_000
    private static let oneGigabyte: Int64 = 1_000_000_000

    /// Upper bound in bytes (exclusive); nil for the last bucket.
    var limit: Int64? {
        switch self {
        case .under1MB: ScanLimits.keepBytes
        case .to10MB: Self.tenMegabytes
        case .to100MB: Self.hundredMegabytes
        case .to1GB: Self.oneGigabyte
        case .over1GB: nil
        }
    }

    var title: TextKey {
        switch self {
        case .under1MB: .bucketUnder1MB
        case .to10MB: .bucketTo10MB
        case .to100MB: .bucketTo100MB
        case .to1GB: .bucketTo1GB
        case .over1GB: .bucketOver1GB
        }
    }
}

struct Statistics {
    var fileCount = 0
    var bytes: Int64 = 0
    var largeFiles = 0
    var sizeClasses: [(sizeClass: SizeBucket, count: Int, bytes: Int64)] = []
}
