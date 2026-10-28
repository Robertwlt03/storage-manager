import Foundation

/// What the cleaner can remove; each kind regenerates by itself or is already thrown away.
enum CleanKind: String, CaseIterable, Identifiable {
    case caches, developer, logs, temp, trash
    var id: Self { self }

    var title: Loc {
        switch self {
        case .caches: .cleanCaches
        case .developer: .cleanDeveloper
        case .logs: .cleanLogs
        case .temp: .cleanTemp
        case .trash: .cleanTrash
        }
    }

    var detail: Loc {
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
    var preselected: Bool { self != .trash }
}

struct CleanItem: Identifiable {
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

    /// Upper bound in bytes (exclusive); nil for the last bucket.
    var limit: Int64? {
        switch self {
        case .under1MB: ScanConfig.keepBytes
        case .to10MB: 10_000_000
        case .to100MB: 100_000_000
        case .to1GB: 1_000_000_000
        case .over1GB: nil
        }
    }

    var title: Loc {
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
    var files = 0
    var bytes: Int64 = 0
    var largeFiles = 0
    var buckets: [(bucket: SizeBucket, count: Int, bytes: Int64)] = []
}
