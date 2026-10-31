import AppKit

/// Everything the user does with Finder, the pasteboard or System Settings; Finder's icons come
/// from `PreviewService`, which may run off the main thread.
enum FinderService {
    static func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    static func copyPath(_ path: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    static func openFullDiskAccessSettings() { NSWorkspace.shared.open(SystemLinks.fullDiskAccess) }

    static func chooseFolders() -> [String] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        return panel.runModal() == .OK
            ? panel.urls.map { url in Paths.withoutSymlinks(url.path) } : []
    }
}
