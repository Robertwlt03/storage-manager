import CoreServices
import Foundation

/// Installed apps with the date macOS last opened them. The date comes from Spotlight, which records it anyway;
/// the app itself tracks nothing.
enum AppUsageService {
    static let appSuffix = ".app"
    private static var folders: [String] { [Paths.applications, Paths.home + "/Applications"] }

    /// Apps in the Applications folders and one level of subfolders; sizes come from the scanned tree.
    static func apps(in root: Node) -> [AppUsage] {
        let fm = FileManager.default
        var paths: [String] = []
        for folder in folders {
            for name in (try? fm.contentsOfDirectory(atPath: folder)) ?? [] {
                let path = folder + "/" + name
                if name.hasSuffix(appSuffix) { paths.append(path); continue }
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
                paths += ((try? fm.contentsOfDirectory(atPath: path)) ?? []).filter { $0.hasSuffix(appSuffix) }.map { path + "/" + $0 }
            }
        }
        return paths.map { path in
            AppUsage(path: path, name: fm.displayName(atPath: path), bundleID: Bundle(path: path)?.bundleIdentifier,
                     lastUsed: lastUsed(path), bytes: root.descendant(at: path)?.bytes ?? 0)
        }
    }

    static func isUnused(_ app: AppUsage, days: Int) -> Bool {
        guard let date = app.lastUsed else { return false }
        return date < Date().addingTimeInterval(-Double(days) * 86_400)
    }

    static func isRunning(_ app: AppUsage) -> Bool {
        guard let id = app.bundleID else { return false }
        return CopyService.isRunning(id)
    }

    /// Moves the app to the Trash (it can be put back from there).
    static func moveToTrash(_ app: AppUsage) throws {
        try FileManager.default.trashItem(at: URL(fileURLWithPath: app.path), resultingItemURL: nil)
    }

    private static func lastUsed(_ path: String) -> Date? {
        guard let item = MDItemCreate(kCFAllocatorDefault, path as CFString) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }
}
