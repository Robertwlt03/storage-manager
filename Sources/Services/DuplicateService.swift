import CryptoKit
import Foundation

// ponytail: APFS clones share their blocks, so removing one frees nothing; telling them apart
// needs the clone ID that macOS does not offer for a path.

/// Finds large files that exist more than once with the same content. The sizes come from the
/// scanned tree, so only files of equal size are read: first a sample, then in full.
nonisolated enum DuplicateService {
    /// Smaller duplicates hardly free space and would mean reading many more files.
    static let smallestBytes: Int64 = 10_000_000
    private static let sampleBytes = 1_000_000
    private static let chunkBytes = 4_000_000

    /// Files of equal size, the biggest size first; only these can be duplicates.
    static func sameSizeGroups(_ files: [Entry]) -> [[Entry]] {
        let candidates = files.filter { file in file.bytes >= smallestBytes }
        return Dictionary(grouping: candidates, by: \.bytes).values
            .filter { group in group.count > 1 }
            .sorted { first, second in first[0].bytes > second[0].bytes }
    }

    /// What keeping one file of each group and removing the others would free.
    static func spareBytes(_ groups: [[Entry]]) -> Int64 {
        groups.reduce(0) { total, group in total + group[0].bytes * Int64(group.count - 1) }
    }

    /// The groups whose files really have the same content, read in the background; ends early
    /// when the calling task is canceled.
    static func confirmed(_ groups: [[Entry]]) async -> [[Entry]] {
        let reading = Task.detached(priority: .utility) {
            split(split(groups, by: sampleDigest), by: fullDigest)
        }
        return await withTaskCancellationHandler {
            await reading.value
        } onCancel: {
            reading.cancel()
        }
    }

    /// Splits each group by the key of its files; files without a key and single files drop out.
    static func split(_ groups: [[Entry]], by key: (String) -> Data?) -> [[Entry]] {
        groups.flatMap { group in
            let keyed = group.compactMap { file in
                file.path.flatMap(key).map { digest in (file, digest) }
            }
            return Dictionary(grouping: keyed, by: \.1).values
                .map { pairs in pairs.map(\.0) }
                .filter { files in files.count > 1 }
        }
    }

    private static func sampleDigest(_ path: String) -> Data? { digest(path, upTo: sampleBytes) }
    private static func fullDigest(_ path: String) -> Data? { digest(path, upTo: .max) }

    private static func digest(_ path: String, upTo limit: Int) -> Data? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        var remaining = limit
        while remaining > 0, !Task.isCancelled {
            let readBytes = readChunk(of: handle, upTo: remaining, into: &hasher)
            guard readBytes > 0 else { break }
            remaining -= readBytes
        }
        return Task.isCancelled ? nil : Data(hasher.finalize())
    }

    /// Adds the next chunk to the hash and returns its length, 0 at the end. The pool frees each
    /// chunk at once; otherwise a large file would stay in memory until the search ends.
    private static func readChunk(of handle: FileHandle, upTo limit: Int, into hasher: inout SHA256)
        -> Int
    {
        autoreleasepool {
            guard let chunk = try? handle.read(upToCount: min(chunkBytes, limit)) else { return 0 }
            hasher.update(data: chunk)
            return chunk.count
        }
    }
}
