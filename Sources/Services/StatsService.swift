import Foundation

/// Key figures and size classes for the start page, all taken from the scanned tree (no extra disk access).
enum StatsService {
    static func compute(root: Node) -> Statistics {
        var s = Statistics(files: root.fileCount, bytes: root.bytes)
        var counts: [SizeBucket: Int] = [:]
        var sizes: [SizeBucket: Int64] = [:]
        var keptCount = 0
        var keptBytes: Int64 = 0

        func walk(_ n: Node) {
            for f in n.files {
                keptCount += 1
                keptBytes += f.bytes
                let b = bucket(f.bytes)
                counts[b, default: 0] += 1
                sizes[b, default: 0] += f.bytes
            }
            n.children.forEach(walk)
        }
        walk(root)

        // Files under 1 MB are folded during the scan; they are everything that was not kept.
        counts[.under1MB] = max(0, root.fileCount - keptCount)
        sizes[.under1MB] = max(0, root.bytes - keptBytes)
        s.largeFiles =
            SearchService.largeFiles(
                atLeast: LargeFileThreshold.bytes(AppSettings.largeFileMB), in: root
            )
            .count
        s.buckets = SizeBucket.allCases.map { ($0, counts[$0] ?? 0, sizes[$0] ?? 0) }
        return s
    }

    static func bucket(_ bytes: Int64) -> SizeBucket {
        SizeBucket.allCases.first { b in b.limit.map { bytes < $0 } ?? true } ?? .over1GB
    }

}
