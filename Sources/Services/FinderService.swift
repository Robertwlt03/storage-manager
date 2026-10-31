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

    /// Asks where to keep a text and writes it there; when that fails, macOS's own alert says why.
    /// False when canceled or not written.
    @discardableResult
    static func save(_ text: String, suggestedName: String) -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = suggestedName
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            NSAlert(error: error).runModal()
            return false
        }
    }

    static func chooseFolders() -> [String] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        return panel.runModal() == .OK
            ? panel.urls.map { url in Paths.withoutSymlinks(url.path) } : []
    }
}
