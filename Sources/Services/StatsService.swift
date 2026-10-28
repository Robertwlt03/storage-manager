import Foundation
import UniformTypeIdentifiers

/// Figures for the statistics page, all taken from the scanned tree (no extra disk access).
enum StatsService {
    static let topTypes = 8

    static func compute(root: Node) -> Statistics {
        var s = Statistics(files: root.fileCount, bytes: root.bytes)
        var types: [String: Int64] = [:]
        var counts: [SizeBucket: Int] = [:], sizes: [SizeBucket: Int64] = [:]
        var keptCount = 0, keptBytes: Int64 = 0

        func walk(_ n: Node) {
            for f in n.files {
                keptCount += 1
                keptBytes += f.bytes
                types[(f.name as NSString).pathExtension.lowercased(), default: 0] += f.bytes
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
        s.largeFiles = SearchService.largeFiles(atLeast: LargeFileThreshold.bytes(AppSettings.largeFileMB), in: root).count
        let sorted = types.sorted { $0.value > $1.value }
        s.types = sorted.prefix(topTypes).map { ($0.key, name(ofExtension: $0.key), $0.value) }
        let rest = sorted.dropFirst(topTypes).reduce(0) { $0 + $1.value }
        if rest > 0 { s.types.append(("", Loc.otherTypes.s, rest)) }
        s.buckets = SizeBucket.allCases.map { ($0, counts[$0] ?? 0, sizes[$0] ?? 0) }
        return s
    }

    static func bucket(_ bytes: Int64) -> SizeBucket {
        SizeBucket.allCases.first { b in b.limit.map { bytes < $0 } ?? true } ?? .over1GB
    }

    /// "MPEG-4 movie (.mp4)" instead of a bare extension; files without one are mostly parts of programs.
    static func name(ofExtension ext: String) -> String {
        guard !ext.isEmpty else { return Loc.typeNoExtension.s }
        let described = UTType(filenameExtension: ext)?.localizedDescription
        return described.map { "\($0) (.\(ext))" } ?? "." + ext
    }
}
