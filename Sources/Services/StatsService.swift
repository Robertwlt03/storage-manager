import Foundation

/// Key figures and size classes for the start page, all taken from the scanned tree (no extra disk access).
enum StatsService {
    static func compute(root: Node) -> Statistics {
        var statistics = Statistics(files: root.fileCount, bytes: root.bytes)
        var filesPerBucket: [SizeBucket: Int] = [:]
        var bytesPerBucket: [SizeBucket: Int64] = [:]
        var keptFiles = 0
        var keptBytes: Int64 = 0

        func countKeptFiles(in folder: Node) {
            for file in folder.files {
                keptFiles += 1
                keptBytes += file.bytes
                let sizeBucket = bucket(for: file.bytes)
                filesPerBucket[sizeBucket, default: 0] += 1
                bytesPerBucket[sizeBucket, default: 0] += file.bytes
            }
            folder.children.forEach(countKeptFiles)
        }
        countKeptFiles(in: root)

        // Files under 1 MB are folded during the scan; they are everything that was not kept.
        filesPerBucket[.under1MB] = max(0, root.fileCount - keptFiles)
        bytesPerBucket[.under1MB] = max(0, root.bytes - keptBytes)
        let largeFileBytes = LargeFileThreshold.bytes(AppSettings.largeFileMB)
        statistics.largeFiles = SearchService.largeFiles(atLeast: largeFileBytes, in: root).count
        statistics.buckets = SizeBucket.allCases.map { sizeBucket in
            (sizeBucket, filesPerBucket[sizeBucket] ?? 0, bytesPerBucket[sizeBucket] ?? 0)
        }
        return statistics
    }

    private static func bucket(for bytes: Int64) -> SizeBucket {
        let fittingBucket = SizeBucket.allCases.first { sizeBucket in
            guard let limit = sizeBucket.limit else { return true }
            return bytes < limit
        }
        return fittingBucket ?? .over1GB
    }
}
