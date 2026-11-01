import Foundation

/// What the cleaner can remove; each kind regenerates by itself or is already thrown away.
nonisolated enum CleanKind: String, CaseIterable, Identifiable {
    case caches, developer, logs, temporary, installers, trash
    var id: Self { self }

    var title: TextKey {
        switch self {
        case .caches: .cleanCaches
        case .developer: .cleanDeveloper
        case .logs: .cleanLogs
        case .temporary: .cleanTemporary
        case .installers: .cleanInstallers
        case .trash: .cleanTrash
        }
    }

    var detail: TextKey {
        switch self {
        case .caches: .cleanCachesDetail
        case .developer: .cleanDeveloperDetail
        case .logs: .cleanLogsDetail
        case .temporary: .cleanTemporaryDetail
        case .installers: .cleanInstallersDetail
        case .trash: .cleanTrashDetail
        }
    }

    /// Same symbol and color as the matching storage category.
    var category: CategoryKind {
        switch self {
        case .caches: .caches
        case .developer: .developer
        case .logs: .library
        case .temporary: .temporary
        case .installers: .downloads
        case .trash: .trash
        }
    }

    /// Selected by default; emptying the Trash and removing downloads stay a deliberate choice.
    var isPreselected: Bool { self != .trash && self != .installers }
}

nonisolated struct CleanItem: Identifiable {
    let kind: CleanKind
    let paths: [String]
    let bytes: Int64
    var id: CleanKind { kind }
}

nonisolated struct AppUsage: Identifiable {
    let path: String
    let name: String
    let bundleID: String?
    let lastUsed: Date?
    var bytes: Int64 = 0
    var id: String { path }
}
