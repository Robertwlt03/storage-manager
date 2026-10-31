import Foundation

/// Thin wrapper around fts(3): physical walk, no chdir, stays on one volume.
nonisolated enum FileTreeWalker {
    private static let walkOptions = FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV
    private static let bytesPerBlock: Int64 = 512
    private static let terminatingZeroLength = 1

    /// Calls `visit` for every entry; returning false stops the walk. Folders in `excluded` are
    /// left out with everything inside. Returns false if stopped, not opened or ended early by an
    /// error.
    @discardableResult
    static func walk(
        _ path: String, excluding excluded: Set<String> = [],
        _ visit: (UnsafeMutablePointer<FTSENT>) -> Bool
    ) -> Bool {
        let pathCopy = strdup(path)
        defer { free(pathCopy) }
        var arguments: [UnsafeMutablePointer<CChar>?] = [pathCopy, nil]
        guard let walkHandle = fts_open(&arguments, walkOptions, nil) else {
            return false
        }
        defer { fts_close(walkHandle) }
        var skippedFolder: UnsafeMutablePointer<FTSENT>?
        while let entry = fts_read(walkHandle) {
            // fts returns a skipped folder once more as FTS_DP; neither visit reaches `visit`.
            if entry == skippedFolder {
                skippedFolder = nil
                continue
            }
            if !excluded.isEmpty && kind(of: entry) == FTS_D
                && excluded.contains(String(cString: entry.pointee.fts_path))
            {
                fts_set(walkHandle, entry, FTS_SKIP)
                skippedFolder = entry
                continue
            }
            if !visit(entry) { return false }
        }
        // fts_read sets errno to 0 at the regular end and to the error when it gives up early.
        return errno == 0
    }

    static func kind(of entry: UnsafeMutablePointer<FTSENT>) -> Int32 {
        Int32(entry.pointee.fts_info)
    }

    static func name(of entry: UnsafeMutablePointer<FTSENT>) -> String {
        let capacity = Int(entry.pointee.fts_namelen) + terminatingZeroLength
        return withUnsafePointer(to: &entry.pointee.fts_name) { namePointer in
            namePointer.withMemoryRebound(to: CChar.self, capacity: capacity) { characters in
                String(cString: characters)
            }
        }
    }

    /// What a file or folder takes on disk, summed over its files; for small entries that the
    /// tree folded away.
    static func allocatedBytes(of path: String) -> Int64 {
        var total: Int64 = 0
        walk(path) { entry in
            if kind(of: entry) == FTS_F, let fileStatus = entry.pointee.fts_statp?.pointee {
                total += allocatedBytes(fileStatus)
            }
            return true
        }
        return total
    }

    /// Allocated bytes on disk, like `du`.
    static func allocatedBytes(_ fileStatus: stat) -> Int64 {
        Int64(fileStatus.st_blocks) * bytesPerBlock
    }
}
