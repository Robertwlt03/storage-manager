import Foundation

/// Thin wrapper around fts(3): physical walk, no chdir, stays on one volume.
enum FTS {
    /// Calls `visit` for every entry; returning false stops the walk. Returns false if stopped or not opened.
    @discardableResult
    static func walk(_ path: String, _ visit: (UnsafeMutablePointer<FTSENT>) -> Bool) -> Bool {
        var argv: [UnsafeMutablePointer<CChar>?] = [strdup(path), nil]
        defer { free(argv[0]) }
        guard let fts = fts_open(&argv, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else {
            return false
        }
        defer { fts_close(fts) }
        while let ent = fts_read(fts) {
            if !visit(ent) { return false }
        }
        return true
    }

    static func info(_ ent: UnsafeMutablePointer<FTSENT>) -> Int32 { Int32(ent.pointee.fts_info) }

    static func name(_ ent: UnsafeMutablePointer<FTSENT>) -> String {
        withUnsafePointer(to: &ent.pointee.fts_name) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(ent.pointee.fts_namelen) + 1) {
                String(cString: $0)
            }
        }
    }

    /// Allocated bytes on disk, like `du`.
    static func allocated(_ st: stat) -> Int64 { Int64(st.st_blocks) * 512 }
}
