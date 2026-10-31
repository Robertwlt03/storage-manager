import Foundation

nonisolated enum VolumeService {
    private static let volumeKeys: [URLResourceKey] = [
        .volumeNameKey, .volumeLocalizedFormatDescriptionKey, .volumeTotalCapacityKey,
        .volumeAvailableCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey, .volumeIsInternalKey,
        .volumeIsRootFileSystemKey,
    ]

    /// All visible mounted volumes, the startup volume first.
    static func all() -> [VolumeInformation] {
        let urls =
            FileManager.default.mountedVolumeURLs(
                includingResourceValuesForKeys: volumeKeys, options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap(volume).sorted(by: isListedBefore)
    }

    static func startup() -> VolumeInformation? { all().first(where: \.isRoot) }

    private static func isListedBefore(_ left: VolumeInformation, _ right: VolumeInformation)
        -> Bool
    {
        if left.isRoot != right.isRoot { return left.isRoot }
        return left.name < right.name
    }

    private static func volume(at url: URL) -> VolumeInformation? {
        guard let values = try? url.resourceValues(forKeys: Set(volumeKeys)),
            let total = values.volumeTotalCapacity, total > 0
        else { return nil }
        let free = Int64(values.volumeAvailableCapacity ?? 0)
        return VolumeInformation(
            path: url.path, name: values.volumeName ?? url.lastPathComponent,
            format: values.volumeLocalizedFormatDescription ?? "", totalBytes: Int64(total),
            freeBytes: free,
            availableBytes: max(free, values.volumeAvailableCapacityForImportantUsage ?? 0),
            isInternal: values.volumeIsInternal ?? false,
            isRoot: values.volumeIsRootFileSystem ?? false)
    }
}
