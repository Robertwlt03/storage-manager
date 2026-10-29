import CoreServices
import Foundation

/// Installed apps with the date macOS last opened them. The date comes from Spotlight, which
/// records it anyway; the app itself tracks nothing.
enum AppUsageService {
    private static let appSuffix = ".app"
    private static let secondsPerDay: TimeInterval = 86_400
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

    static func isUnused(_ app: AppUsage, days: Int) -> Bool {
        guard let lastUsed = app.lastUsed else { return false }
        return lastUsed < Date().addingTimeInterval(-Double(days) * secondsPerDay)
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
            for name in contents(of: folder) {
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
        contents(of: folder)
            .filter { name in name.hasSuffix(appSuffix) }
            .map { name in folder + "/" + name }
    }

    private static func contents(of folder: String) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
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
