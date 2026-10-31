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

    /// What a removal of `removedBytes` really freed, from the free space before and after it. At
    /// most what was removed: other removals and macOS itself may free space at the same time.
    /// Nothing when either reading is missing.
    static func freedBytes(before: Int64?, after: Int64?, removedBytes: Int64) -> Int64 {
        guard let before, let after else { return 0 }
        return min(max(after - before, 0), removedBytes)
    }

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
