import Foundation

/// The used space after one full scan; together the points draw the history.
nonisolated struct HistoryPoint: Codable, Equatable {
    let date: Date
    let usedBytes: Int64
}

/// The sizes of the bigger folders near the top of each area after one full scan, by path.
nonisolated struct FolderSizes: Codable, Equatable {
    let date: Date
    /// The scanned areas and whether the scan could read every folder; scans compare only when
    /// both match.
    let areas: [String]
    let hadFullAccess: Bool
    let bytes: [String: Int64]
}

/// The folders that grew most between two full scans, the biggest growth first.
nonisolated struct Growth: Equatable {
    let since: Date
    let folders: [GrownFolder]
}

nonisolated struct GrownFolder: Identifiable, Equatable {
    let path: String
    let grownBytes: Int64
    var id: String { path }
}
