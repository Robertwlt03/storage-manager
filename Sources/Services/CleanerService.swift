import AppKit

/// Finds and removes files that regenerate by themselves (caches), are old (logs, temporary files)
/// or already thrown away (Trash). Caches of running apps and of macOS itself are left alone.
nonisolated enum CleanerService {
    private static let cachesFolder = Paths.home + "/Library/Caches"
    private static let logsFolder = Paths.home + "/Library/Logs"
    private static let trashFolder = Paths.home + "/.Trash"
    private static var temporaryFolder: String {
        Paths.temporaryArea + "/" + TemporaryAreaPart.temporaryFiles.rawValue
    }
    private static let systemPrefix = "com.apple."
    private static let developerFolders = [
        "~/Library/Developer/Xcode/DerivedData", "~/Library/Developer/CoreSimulator/Caches",
        "~/.npm/_cacache", "~/.gradle/caches", "~/.cache",
    ]

    /// Lists what could go; `size` comes from the scanned tree, so no second walk over the disk is
    /// needed. Entries under 1 MB are folded in the tree and count as zero, which is negligible
    /// here.
    static func candidates(size: (String) -> Int64) -> [CleanItem] {
        CleanKind.allCases.map { kind in
            let paths = paths(for: kind)
            let bytes = paths.reduce(0) { total, path in total + size(path) }
            return CleanItem(kind: kind, paths: paths, bytes: bytes)
        }
    }

    /// Removes everything listed; returns how many entries could not be removed.
    static func clean(_ items: [CleanItem]) -> Int {
        var failed = 0
        for path in items.flatMap(\.paths) {
            do { try FileManager.default.removeItem(atPath: path) } catch { failed += 1 }
        }
        return failed
    }

    private static func paths(for kind: CleanKind) -> [String] {
        switch kind {
        case .caches:
            return removableCaches()
        case .developer:
            return developerFolders.map(Paths.expand).filter(Paths.exists)
        case .logs:
            return entries(of: logsFolder)
                .filter { path in isOlder(path, thanDays: CleanUpRules.logMinimumAgeDays) }
        case .temporary:
            return entries(of: temporaryFolder)
                .filter { path in isOlder(path, thanDays: CleanUpRules.temporaryMinimumAgeDays) }
        case .trash:
            return entries(of: trashFolder)
        }
    }

    private static func removableCaches() -> [String] {
        let runningApps = NSWorkspace.shared.runningApplications
        let runningBundleIDs = Set(runningApps.compactMap(\.bundleIdentifier))
        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        return entries(of: cachesFolder)
            .filter { path in
                let name = (path as NSString).lastPathComponent
                return !name.hasPrefix(systemPrefix) && !runningBundleIDs.contains(name)
                    && name != ownBundleID
            }
    }

    private static func entries(of folder: String) -> [String] {
        FileSystem.names(in: folder).map { name in folder + "/" + name }
    }

    private static func isOlder(_ path: String, thanDays days: Int) -> Bool {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        guard let modified = attributes?[.modificationDate] as? Date else { return false }
        return modified < FileSystem.date(daysBefore: days)
    }
}
