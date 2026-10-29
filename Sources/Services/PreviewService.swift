import AppKit
import QuickLookThumbnailing

/// Quick Look thumbnails, the same pictures Finder shows in its icon view: the image itself for
/// photos, the first frame of a video, the first page of a PDF. Each path is rendered once and kept
/// in memory.
enum PreviewService {
    private static let fallbackScreenScale: CGFloat = 2
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = ScanLimits.iconCacheLimit
        return cache
    }()

    /// nil when there is no real preview (folders, unknown types); the caller keeps the Finder icon
    /// then.
    @MainActor static func thumbnail(_ path: String, size: CGFloat) async -> NSImage? {
        let key = "\(path)|\(Int(size))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let request = QLThumbnailGenerator.Request(
            fileAt: URL(fileURLWithPath: path), size: CGSize(width: size, height: size),
            scale: NSScreen.main?.backingScaleFactor ?? fallbackScreenScale,
            representationTypes: .thumbnail)
        guard
            let image = try? await QLThumbnailGenerator.shared
                .generateBestRepresentation(for: request).nsImage
        else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
