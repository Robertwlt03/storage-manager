import Foundation

/// How the storage changes from one full scan to the next: the used space over time and the
/// folders that grew most. Everything comes from the scanned tree, so it costs no extra disk
/// access.
nonisolated enum HistoryService {
    /// About a year of daily scans; older points fall out.
    static let keptPoints = 365
    /// Folders this many levels below an area are compared, so a growing Downloads folder or a
    /// cache inside Library shows by its own name.
    static let comparedDepth = 3
    /// Smaller folders are left out, which keeps the stored list short.
    static let smallestComparedBytes: Int64 = 50_000_000
    /// Less growth than this is everyday change and not listed.
    static let smallestListedGrowth: Int64 = 100_000_000
    static let listedFolders = 5
    /// A folder steps aside when one of its subfolders explains this share of its growth.
    static let explainedShare = 0.8

    static func adding(_ point: HistoryPoint, to points: [HistoryPoint]) -> [HistoryPoint] {
        Array((points + [point]).suffix(keptPoints))
    }

    static func folderSizes(
        of root: Node, at date: Date, excluded: Set<String>, hadFullAccess: Bool
    ) -> FolderSizes {
        var bytes: [String: Int64] = [:]
        for area in root.children { collect(area, depth: 0, into: &bytes) }
        return FolderSizes(
            date: date, areas: Set(root.children.map(\.path)), excluded: excluded,
            hadFullAccess: hadFullAccess, bytes: bytes)
    }

    private static func collect(_ folder: Node, depth: Int, into bytes: inout [String: Int64]) {
        guard folder.bytes >= smallestComparedBytes else { return }
        bytes[folder.path] = folder.bytes
        guard depth < comparedDepth else { return }
        for child in folder.children { collect(child, depth: depth + 1, into: &bytes) }
    }

    /// A folder missing from the earlier list was smaller than `smallestComparedBytes` then, so its
    /// growth counts from zero. Nil when the two scans saw different areas, excluded different
    /// folders or had different access: folders that only became visible would look grown.
    static func growth(from earlier: FolderSizes, to later: FolderSizes) -> Growth? {
        guard earlier.areas == later.areas, earlier.excluded == later.excluded,
            earlier.hadFullAccess == later.hadFullAccess
        else { return nil }
        // ponytail: overstates such a folder's growth by at most smallestComparedBytes; keep
        // smaller folders too if that ever shows in the list.
        let grown = later.bytes.compactMap { path, bytes -> GrownFolder? in
            let grownBytes = bytes - (earlier.bytes[path] ?? 0)
            guard grownBytes >= smallestListedGrowth else { return nil }
            return GrownFolder(path: path, grownBytes: grownBytes)
        }
        let specific = grown.filter { folder in !isExplained(folder, by: grown) }
        let biggestFirst = specific.sorted { first, second in first.grownBytes > second.grownBytes }
        return Growth(since: earlier.date, folders: Array(biggestFirst.prefix(listedFolders)))
    }

    private static func isExplained(_ folder: GrownFolder, by grown: [GrownFolder]) -> Bool {
        grown.contains { other in
            other.path.hasPrefix(folder.path + "/")
                && Double(other.grownBytes) >= explainedShare * Double(folder.grownBytes)
        }
    }
}

/// The history in the app's own settings, as JSON; nothing leaves the Mac.
struct HistoryStore {
    var defaults = UserDefaults.standard

    var points: [HistoryPoint] { read([HistoryPoint].self, SettingsKey.historyPoints) ?? [] }

    /// The two newest folder lists, from the last full scan and the one before it.
    var growth: Growth? {
        guard let earlier = read(FolderSizes.self, SettingsKey.previousFolderSizes),
            let later = read(FolderSizes.self, SettingsKey.latestFolderSizes)
        else { return nil }
        return HistoryService.growth(from: earlier, to: later)
    }

    /// The newest folder list becomes the one before, the given one the newest.
    func record(_ points: [HistoryPoint], latest sizes: FolderSizes) {
        write(points, SettingsKey.historyPoints)
        if let latest = defaults.data(forKey: SettingsKey.latestFolderSizes) {
            defaults.set(latest, forKey: SettingsKey.previousFolderSizes)
        }
        write(sizes, SettingsKey.latestFolderSizes)
    }

    private func read<Value: Decodable>(_ type: Value.Type, _ key: String) -> Value? {
        defaults.data(forKey: key)
            .flatMap { data in
                try? JSONDecoder().decode(type, from: data)
            }
    }

    private func write(_ value: some Encodable, _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
