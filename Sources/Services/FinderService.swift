import AppKit
import SwiftUI

/// Everything that talks to Finder, the pasteboard or System Settings.
enum FinderService {
    static func icon(_ path: String) -> Image { Image(nsImage: NSWorkspace.shared.icon(forFile: path)) }
    static func reveal(_ path: String) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }

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
        return panel.runModal() == .OK ? panel.urls.map { Paths.real($0.path) } : []
    }
}
