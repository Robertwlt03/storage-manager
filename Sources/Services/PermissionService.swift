import Foundation

/// Full Disk Access replaces the single prompts for Desktop, Documents, Downloads, iCloud Drive, other apps' data
/// and external volumes. Apps cannot request it with a dialog; they can only check it and open System Settings.
enum PermissionService {
    /// A file that only processes with Full Disk Access may open; reading it never triggers a prompt.
    private static let probePath = Paths.home + "/Library/Application Support/com.apple.TCC/TCC.db"

    static var hasFullDiskAccess: Bool {
        let fd = open(probePath, O_RDONLY)
        guard fd >= 0 else { return false }
        close(fd)
        return true
    }
}
