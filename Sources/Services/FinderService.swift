import AppKit
import SwiftUI

/// Everything that talks to Finder, the pasteboard or System Settings.
enum FinderService {
    /// Finder icons are looked up once per path: rows are rebuilt often (search, sorting, scrolling) and each lookup
    /// asks Launch Services and the disk again.
    static func icon(_ path: String) -> Image { Image(nsImage: iconImage(path)) }

    static func iconImage(_ path: String) -> NSImage {
        if let cached = icons.object(forKey: path as NSString) { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        icons.setObject(image, forKey: path as NSString)
        return image
    }

    private static let icons: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = ScanConfig.iconCacheLimit
        return cache
    }()
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
        return panel.runModal() == .OK ? panel.urls.map { Paths.real($0.path) } : []
    }
}
