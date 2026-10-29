import AppKit

/// Finds and removes files that regenerate by themselves (caches), are old (logs, temporary files)
/// or already thrown away (Trash). Caches of running apps and of macOS itself are left alone.
enum CleanerService {
    private static let cachesFolder = Paths.home + "/Library/Caches"
    private static let logsFolder = Paths.home + "/Library/Logs"
    private static let trashFolder = Paths.home + "/.Trash"
    private static var tempFolder: String { Paths.tempArea + "/" + TempPart.t.rawValue }
    private static let systemPrefix = "com.apple."
    private static let developerFolders = [
        "~/Library/Developer/Xcode/DerivedData", "~/Library/Developer/CoreSimulator/Caches",
        "~/.npm/_cacache", "~/.gradle/caches", "~/.cache",
    ]

    /// Lists what could go; `size` comes from the scanned tree, so no second walk over the disk is needed.
    /// Entries under 1 MB are folded in the tree and count as zero, which is negligible here.
    static func candidates(size: (String) -> Int64) -> [CleanItem] {
        CleanKind.allCases.map { kind in
            let paths = paths(for: kind)
            return CleanItem(kind: kind, paths: paths, bytes: paths.reduce(0) { $0 + size($1) })
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
            let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
            let own = Bundle.main.bundleIdentifier ?? ""
            return entries(of: cachesFolder)
                .filter { path in
                    let name = (path as NSString).lastPathComponent
                    return !name.hasPrefix(systemPrefix) && !running.contains(name) && name != own
                }
        case .developer:
            return developerFolders.map(Paths.expand).filter(Paths.exists)
        case .logs:
            return entries(of: logsFolder).filter { olderThan($0, days: CleanConfig.logMinAgeDays) }
        case .temp:
            return entries(of: tempFolder)
                .filter { olderThan($0, days: CleanConfig.tempMinAgeDays) }
        case .trash:
            return entries(of: trashFolder)
        }
    }

    private static func entries(of folder: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? [])
            .map { folder + "/" + $0 }
    }

    private static func olderThan(_ path: String, days: Int) -> Bool {
        guard
            let date = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate]
                as? Date
        else { return false }
        return date < Date().addingTimeInterval(-Double(days) * 86_400)
    }
}
