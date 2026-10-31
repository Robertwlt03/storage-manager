import AppKit
import QuickLookThumbnailing

/// The pictures of files: Finder's icon, and Quick Look thumbnails, the same pictures Finder shows
/// in its icon view (the image itself for photos, the first frame of a video, the first page of a
/// PDF). It reads the disk, so it is free of the main thread.
nonisolated enum PreviewService {
    // NSCache is safe to use from any thread (see its documentation), which the compiler cannot
    // see on its own: the macOS 27 SDK still does not mark it Sendable.
    nonisolated(unsafe) private static let thumbnails: NSCache<NSString, NSImage> = .images()
    nonisolated(unsafe) private static let finderIcons: NSCache<NSString, NSImage> = .images()

    /// Finder icons are looked up once per path: rows are rebuilt often (search, sorting,
    /// scrolling) and each lookup asks Launch Services and the disk again.
    static func finderIcon(_ path: String) -> NSImage {
        if let cached = finderIcons.object(forKey: path as NSString) { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        finderIcons.setObject(image, forKey: path as NSString)
        return image
    }

    /// nil when there is no real preview (folders, unknown types); the caller keeps the Finder icon
    /// then. The scale is the screen's, which only the view knows.
    @concurrent
    static func thumbnail(_ path: String, size: CGFloat, scale: CGFloat) async -> NSImage? {
        let key = "\(path)|\(Int(size))" as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }
        let request = QLThumbnailGenerator.Request(
            fileAt: URL(fileURLWithPath: path), size: CGSize(width: size, height: size),
            scale: scale, representationTypes: .thumbnail)
        guard
            let image = try? await QLThumbnailGenerator.shared
                .generateBestRepresentation(for: request).nsImage
        else { return nil }
        thumbnails.setObject(image, forKey: key)
        return image
    }
}

nonisolated extension NSCache where KeyType == NSString, ObjectType == NSImage {
    /// Icons and thumbnails stay in memory up to a limit; macOS empties the cache when memory gets
    /// tight.
    static func images() -> NSCache<NSString, NSImage> {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = ScanLimits.maximumCachedImages
        return cache
    }
}
