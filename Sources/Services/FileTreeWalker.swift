import Foundation

/// Thin wrapper around fts(3): physical walk, no chdir, stays on one volume.
enum FileTreeWalker {
    private static let walkOptions = FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV
    private static let bytesPerBlock: Int64 = 512
    private static let terminatingZeroLength = 1

    /// Calls `visit` for every entry; returning false stops the walk. Returns false if stopped or
    /// not opened.
    @discardableResult
    static func walk(_ path: String, _ visit: (UnsafeMutablePointer<FTSENT>) -> Bool) -> Bool {
        let pathCopy = strdup(path)
        defer { free(pathCopy) }
        var arguments: [UnsafeMutablePointer<CChar>?] = [pathCopy, nil]
        guard let walkHandle = fts_open(&arguments, walkOptions, nil) else {
            return false
        }
        defer { fts_close(walkHandle) }
        while let entry = fts_read(walkHandle) {
            if !visit(entry) { return false }
        }
        return true
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

    /// Allocated bytes on disk, like `du`.
    static func allocatedBytes(_ fileStatus: stat) -> Int64 {
        Int64(fileStatus.st_blocks) * bytesPerBlock
    }
}
