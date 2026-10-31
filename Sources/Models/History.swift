import Foundation

/// The used space after one full scan; together the points draw the history.
nonisolated struct HistoryPoint: Codable, Equatable {
    let date: Date
    let usedBytes: Int64
}

/// The sizes of the bigger folders near the top of each area after one full scan, by path.
nonisolated struct FolderSizes: Codable {
    let date: Date
    /// The scanned areas, the excluded folders and whether the scan could read every folder;
    /// scans compare only when all three match, so nothing looks grown just because it became
    /// visible.
    let areas: Set<String>
    let excluded: Set<String>
    let hadFullAccess: Bool
    let bytes: [String: Int64]
}

/// The folders that grew most between two full scans, the biggest growth first.
nonisolated struct Growth {
    let since: Date
    let folders: [GrownFolder]
}

nonisolated struct GrownFolder: Identifiable {
    let path: String
    let grownBytes: Int64
    var id: String { path }
}
