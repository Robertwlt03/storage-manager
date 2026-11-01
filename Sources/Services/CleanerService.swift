import AppKit

/// Finds and removes files that regenerate by themselves (caches), are old (logs, temporary files,
/// installers) or already thrown away (Trash). Caches of running apps and of macOS itself are left
/// alone.
nonisolated enum CleanerService {
    /// Moves a file, folder or app to the Trash, from where it can be put back.
    static func moveToTrash(_ path: String) throws {
        try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
    }

    private static let cachesFolder = Paths.home + "/Library/Caches"
    private static let logsFolder = Paths.home + "/Library/Logs"
    private static let trashFolder = Paths.home + "/.Trash"
    private static let downloadsFolder = Paths.home + "/Downloads"
    /// Disk images and installer packages; once the app is installed they are no longer needed.
    private static let installerExtensions: Set<String> = ["dmg", "pkg", "mpkg", "xip"]
    private static var temporaryFolder: String {
        Paths.temporaryArea + "/" + TemporaryAreaPart.temporaryFiles.rawValue
    }
    private static let systemPrefix = "com.apple."
    private static let developerFolders = [
        "~/Library/Developer/Xcode/DerivedData", "~/Library/Developer/CoreSimulator/Caches",
        "~/.npm/_cacache", "~/.gradle/caches", "~/.cache",
    ]

    /// What could go, per kind, without the excluded folders and what lies in them; the sizes come
    /// from the scanned tree, so there is no second walk.
    static func removablePaths(
        of kinds: [CleanKind] = CleanKind.allCases, excluding excluded: Set<String> = []
    ) -> [(kind: CleanKind, paths: [String])] {
        kinds.map { kind in
            (kind, paths(for: kind).filter { path in !ScanService.liesIn(path, anyOf: excluded) })
        }
    }

    /// The clean-up items with their sizes: from the scanned tree where it has the entry, measured
    /// on the disk where the tree folded it away (under 1 MB), so a folder of many small logs still
    /// counts. The tree sizes are read by the caller, which owns the tree.
    static func items(_ listed: [(kind: CleanKind, paths: [String], treeBytes: [Int64?])])
        -> [CleanItem]
    {
        listed.map { kind, paths, treeBytes in
            let bytes = zip(paths, treeBytes)
                .reduce(0) { total, entry in
                    total + (entry.1 ?? FileTreeWalker.allocatedBytes(of: entry.0))
                }
            return CleanItem(kind: kind, paths: paths, bytes: bytes)
        }
    }

    /// Removes what is listed and still removable now: an app may have started or a temporary file
    /// may have changed since the list was made. Returns how many entries could not be removed.
    static func clean(_ items: [CleanItem]) -> Int {
        let stillRemovable = Set(removablePaths(of: items.map(\.kind)).flatMap(\.paths))
        var failed = 0
        for path in items.flatMap(\.paths) where stillRemovable.contains(path) {
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
        case .installers:
            return entries(of: downloadsFolder)
                .filter { path in
                    isInstaller(path)
                        && wasAdded(path, beforeDays: CleanUpRules.installerMinimumAgeDays)
                }
        case .trash:
            return entries(of: trashFolder)
        }
    }

    static func isInstaller(_ path: String) -> Bool {
        installerExtensions.contains((path as NSString).pathExtension.lowercased())
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

    /// When the file came into its folder, which download tools that keep the server's date do not
    /// change; an unreadable date keeps the file.
    private static func wasAdded(_ path: String, beforeDays days: Int) -> Bool {
        let values = try? URL(filePath: path).resourceValues(forKeys: [.addedToDirectoryDateKey])
        guard let added = values?.addedToDirectoryDate else { return false }
        return added < FileSystem.date(daysBefore: days)
    }

    /// A folder counts as old only when nothing inside it changed either; the walk stops at the
    /// first recent entry.
    private static func isOlder(_ path: String, thanDays days: Int) -> Bool {
        let cutoff = Int(FileSystem.date(daysBefore: days).timeIntervalSince1970)
        return FileTreeWalker.walk(path) { entry in
            // An entry whose date cannot be read could be new, so it keeps the folder.
            guard let fileStatus = entry.pointee.fts_statp?.pointee,
                FileTreeWalker.kind(of: entry) != FTS_NS
            else { return false }
            return fileStatus.st_mtimespec.tv_sec < cutoff
        }
    }
}
