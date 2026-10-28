import Foundation

enum VolumeService {
    private static let keys: [URLResourceKey] = [
        .volumeNameKey, .volumeLocalizedFormatDescriptionKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey, .volumeIsInternalKey, .volumeIsRootFileSystemKey,
    ]

    /// All visible mounted volumes, the startup volume first.
    static func all() -> [VolumeInfo] {
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap(info).sorted { ($0.isRoot ? 0 : 1, $0.name) < ($1.isRoot ? 0 : 1, $1.name) }
    }

    static func startup() -> VolumeInfo? { all().first { $0.isRoot } }

    private static func info(_ url: URL) -> VolumeInfo? {
        guard let v = try? url.resourceValues(forKeys: Set(keys)), let total = v.volumeTotalCapacity, total > 0 else { return nil }
        let free = Int64(v.volumeAvailableCapacity ?? 0)
        return VolumeInfo(path: url.path, name: v.volumeName ?? url.lastPathComponent,
                          format: v.volumeLocalizedFormatDescription ?? "", total: Int64(total), free: free,
                          available: max(free, v.volumeAvailableCapacityForImportantUsage ?? 0),
                          isInternal: v.volumeIsInternal ?? false, isRoot: v.volumeIsRootFileSystem ?? false)
    }
}
