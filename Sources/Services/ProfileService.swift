import Foundation

/// File types, counts and date range below a folder, for the info sheet (a second fts pass on
/// demand).
nonisolated enum ProfileService {
    private static let packageSuffixes = [".app", ".bundle", ".framework"]
    private static let shownTypeCount = 10

    static func basics(of path: String) -> FileBasics {
        let values = try? URL(fileURLWithPath: path)
            .resourceValues(forKeys: [
                .contentModificationDateKey, .creationDateKey, .localizedTypeDescriptionKey,
            ])
        return FileBasics(
            kind: values?.localizedTypeDescription, modified: values?.contentModificationDate,
            created: values?.creationDate)
    }

    static func profile(_ path: String) -> FolderProfile {
        var profile = FolderProfile()
        var bytesPerType: [String: Int64] = [:]
        var filesPerType: [String: Int] = [:]
        var oldestModification = Int.max
        var newestModification = 0
        var visitedEntries = 0

        FileTreeWalker.walk(path) { entry in
            visitedEntries += 1
            if visitedEntries & ScanLimits.cancelCheckMask == 0 && Task.isCancelled { return false }
            switch FileTreeWalker.kind(of: entry) {
            case FTS_D:
                profile.folders += 1
                let folderName = FileTreeWalker.name(of: entry)
                if packageSuffixes.contains(where: folderName.hasSuffix) { profile.packages += 1 }
            case FTS_F:
                guard let fileStatus = entry.pointee.fts_statp?.pointee else { return true }
                profile.files += 1
                let fileType = typeName(of: FileTreeWalker.name(of: entry))
                bytesPerType[fileType, default: 0] += FileTreeWalker.allocatedBytes(fileStatus)
                filesPerType[fileType, default: 0] += 1
                oldestModification = min(oldestModification, fileStatus.st_mtimespec.tv_sec)
                newestModification = max(newestModification, fileStatus.st_mtimespec.tv_sec)
            default:
                break
            }
            return true
        }
        if profile.files > 0 {
            profile.oldest = Date(timeIntervalSince1970: TimeInterval(oldestModification))
            profile.newest = Date(timeIntervalSince1970: TimeInterval(newestModification))
        }
        profile.folders = max(0, profile.folders - 1)  // without the folder itself
        profile.types = largestTypes(bytesPerType: bytesPerType, filesPerType: filesPerType)
        return profile
    }

    private static func typeName(of fileName: String) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        return fileExtension.isEmpty ? TextKey.noExtension.translated : "." + fileExtension
    }

    private static func largestTypes(
        bytesPerType: [String: Int64], filesPerType: [String: Int]
    ) -> [(fileExtension: String, bytes: Int64, count: Int)] {
        bytesPerType.sorted { left, right in left.value > right.value }
            .prefix(shownTypeCount)
            .map { fileType in (fileType.key, fileType.value, filesPerType[fileType.key] ?? 0) }
    }
}
