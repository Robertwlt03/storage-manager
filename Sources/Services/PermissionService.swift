import Foundation

/// Full Disk Access replaces the single prompts for Desktop, Documents, Downloads, iCloud Drive,
/// other apps' data and external volumes. Apps cannot request it with a dialog; they can only check
/// it and open System Settings.
nonisolated enum PermissionService {
    /// Folders only Full Disk Access may list; listing them without it fails quietly, without a
    /// prompt. Several, because not every Mac has every folder, and macOS 27 no longer lets even
    /// Full Disk Access open the TCC database that older checks relied on.
    private static let probeFolders = [
        "/Library/Safari", "/Library/Mail", "/Library/Messages", "/Library/Cookies",
    ]
    .map { folder in Paths.home + folder }

    static var hasFullDiskAccess: Bool {
        probeFolders.contains { path in
            guard let folderStream = opendir(path) else { return false }
            closedir(folderStream)
            return true
        }
    }
}
