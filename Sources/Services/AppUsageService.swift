import CoreServices
import Foundation

/// Installed apps with the date macOS last opened them. The date comes from Spotlight, which
/// records it anyway; the app itself tracks nothing.
enum AppUsageService {
    private static let appSuffix = ".app"
    private static var folders: [String] { [Paths.applications, Paths.home + "/Applications"] }

    /// Apps in the Applications folders and one level of subfolders; sizes come from the scanned
    /// tree.
    static func apps(in root: Node) -> [AppUsage] {
        appPaths()
            .map { path in
                AppUsage(
                    path: path, name: FileManager.default.displayName(atPath: path),
                    bundleID: Bundle(path: path)?.bundleIdentifier,
                    lastUsed: lastUsed(path), bytes: root.descendant(at: path)?.bytes ?? 0)
            }
    }

    /// Apps not opened for `days`, the longest unused first. Apps without a date are left out,
    /// because Spotlight simply may not know them yet.
    static func unused(_ apps: [AppUsage], days: Int, now: Date = Date()) -> [AppUsage] {
        let cutoff = FileSystem.date(daysBefore: days, now)
        return
            apps
            .filter { app in app.lastUsed.map { lastUsed in lastUsed < cutoff } ?? false }
            .sorted { first, second in
                (first.lastUsed ?? .distantPast) < (second.lastUsed ?? .distantPast)
            }
    }

    static func isRunning(_ app: AppUsage) -> Bool {
        guard let bundleID = app.bundleID else { return false }
        return CopyService.isRunning(bundleID)
    }

    /// Moves the app to the Trash (it can be put back from there).
    static func moveToTrash(_ app: AppUsage) throws {
        try FileManager.default.trashItem(at: URL(fileURLWithPath: app.path), resultingItemURL: nil)
    }

    private static func appPaths() -> [String] {
        var paths: [String] = []
        for folder in folders {
            for name in FileSystem.names(in: folder) {
                let path = folder + "/" + name
                if name.hasSuffix(appSuffix) {
                    paths.append(path)
                } else if isFolder(path) {
                    paths += appPaths(directlyIn: path)
                }
            }
        }
        return paths
    }

    private static func appPaths(directlyIn folder: String) -> [String] {
        FileSystem.names(in: folder)
            .filter { name in name.hasSuffix(appSuffix) }
            .map { name in folder + "/" + name }
    }

    private static func isFolder(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private static func lastUsed(_ path: String) -> Date? {
        guard let item = MDItemCreate(kCFAllocatorDefault, path as CFString) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }
}
