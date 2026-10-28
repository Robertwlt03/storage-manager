import Foundation

/// Figures for the statistics page, all taken from the scanned tree (no extra disk access).
enum StatsService {
    static let topTypes = 8

    static func compute(root: Node) -> Statistics {
        var s = Statistics(files: root.fileCount, bytes: root.bytes)
        var types: [String: Int64] = [:]
        var counts: [SizeBucket: Int] = [:]
        var kept = 0

        func walk(_ n: Node) {
            for f in n.files {
                kept += 1
                let ext = (f.name as NSString).pathExtension.lowercased()
                types[ext.isEmpty ? Loc.noExtension.s : "." + ext, default: 0] += f.bytes
                counts[bucket(f.bytes), default: 0] += 1
            }
            n.children.forEach(walk)
        }
        walk(root)

        // Files under 1 MB are folded during the scan; they are the files that were not kept.
        counts[.under1MB] = max(0, root.fileCount - kept)
        s.largeFiles = SearchService.largeFiles(atLeast: LargeFileThreshold.bytes(AppSettings.largeFileMB), in: root).count
        let sorted = types.sorted { $0.value > $1.value }
        s.types = sorted.prefix(topTypes).map { ($0.key, $0.value) }
        let rest = sorted.dropFirst(topTypes).reduce(0) { $0 + $1.value }
        if rest > 0 { s.types.append((Loc.otherTypes.s, rest)) }
        s.buckets = SizeBucket.allCases.map { ($0, counts[$0] ?? 0) }
        return s
    }

    static func bucket(_ bytes: Int64) -> SizeBucket {
        SizeBucket.allCases.first { b in b.limit.map { bytes < $0 } ?? true } ?? .over1GB
    }
}
