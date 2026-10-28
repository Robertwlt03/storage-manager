import Foundation

/// One folder in the scanned tree. Sizes are allocated bytes like `du` (APFS clones count in full).
final class Node: Identifiable, Hashable {
    let name: String
    private(set) weak var parent: Node?
    var bytes: Int64 = 0
    var fileCount = 0
    var children: [Node] = []  // folders of at least `Scanner.keepBytes`, biggest first
    var files: [FileItem] = []  // files of at least `Scanner.keepBytes`, biggest first
    var restBytes: Int64 = 0  // smaller files and folders directly inside, folded into one row
    var restCount = 0

    init(name: String, parent: Node?) {
        self.name = name
        self.parent = parent
    }

    /// Root nodes carry their absolute path as name.
    var path: String { parent.map { $0.isVirtual ? name : $0.path + "/" + name } ?? name }
    var isVirtual: Bool { parent == nil && name.isEmpty }
    var url: URL { URL(fileURLWithPath: path) }

    func child(named n: String) -> Node? { children.first { $0.name == n } }

    func attach(to p: Node) {
        parent = p
        p.children.append(self)
        p.bytes += bytes
        p.fileCount += fileCount
    }

    /// Removes this folder from the tree and subtracts its size from every ancestor.
    func detach() {
        var p = parent
        while let a = p {
            a.bytes -= bytes
            a.fileCount -= fileCount
            p = a.parent
        }
        parent?.children.removeAll { $0 === self }
    }

    static func == (a: Node, b: Node) -> Bool { a === b }
    func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
}

struct FileItem: Identifiable, Hashable {
    let path: String
    let bytes: Int64
    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
    var url: URL { URL(fileURLWithPath: path) }
}

enum Scanner {
    /// ponytail: folders and files below 1 MB are folded into one "kleinere Objekte" row per folder;
    /// this keeps the tree small (memory, energy). Lower it if someone needs to see tiny files.
    static let keepBytes: Int64 = 1 << 20

    struct Progress { var files = 0; var bytes: Int64 = 0 }

    /// Walks `path` once with fts(3) and returns the folder tree, or nil if cancelled.
    /// Runs on the caller's thread; call it from a low-priority task.
    static func scan(_ path: String, unreadable: inout Int, progress: (Progress) -> Void) -> Node? {
        var argv: [UnsafeMutablePointer<CChar>?] = [strdup(path), nil]
        defer { free(argv[0]) }
        guard let fts = fts_open(&argv, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else { return nil }
        defer { fts_close(fts) }

        var stack: [Node] = []
        var root: Node?
        var seenLinks = Set<UInt64>()  // hard-linked files count once, like du
        var p = Progress()
        var lastReport = Date()
        var counter = 0

        while let ent = fts_read(fts) {
            counter += 1
            if counter & 0xFFF == 0 {
                if Task.isCancelled { return nil }
                if Date().timeIntervalSince(lastReport) > 0.5 {  // throttle UI updates
                    progress(p)
                    lastReport = Date()
                }
            }
            let e = ent.pointee
            switch Int32(e.fts_info) {
            case FTS_D:
                let node = Node(name: stack.isEmpty ? path : name(of: ent), parent: stack.last)
                if root == nil { root = node }
                stack.append(node)
            case FTS_DP, FTS_DNR:  // an unreadable folder arrives as FTS_D first and as FTS_DNR instead of FTS_DP
                if Int32(e.fts_info) == FTS_DNR { unreadable += 1 }
                guard let node = stack.popLast() else { continue }
                node.children.sort { $0.bytes > $1.bytes }
                node.files.sort { $0.bytes > $1.bytes }
                if let parent = stack.last {
                    parent.bytes += node.bytes
                    parent.fileCount += node.fileCount
                    if node.bytes >= keepBytes { parent.children.append(node) } else {
                        parent.restBytes += node.bytes
                        parent.restCount += 1
                    }
                }
            case FTS_F, FTS_SL, FTS_SLNONE, FTS_DEFAULT:
                guard let st = e.fts_statp?.pointee, let dir = stack.last else { continue }
                if st.st_nlink > 1 && !seenLinks.insert(UInt64(st.st_ino)).inserted { continue }
                let size = Int64(st.st_blocks) * 512
                dir.bytes += size
                dir.fileCount += 1
                p.files += 1
                p.bytes += size
                if size >= keepBytes { dir.files.append(FileItem(path: dir.path + "/" + name(of: ent), bytes: size)) } else {
                    dir.restBytes += size
                    dir.restCount += 1
                }
            case FTS_ERR, FTS_NS:
                unreadable += 1
            default:
                break
            }
        }
        progress(p)
        return root
    }

    private static func name(of ent: UnsafeMutablePointer<FTSENT>) -> String {
        withUnsafePointer(to: &ent.pointee.fts_name) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(ent.pointee.fts_namelen) + 1) { String(cString: $0) }
        }
    }

    // MARK: Folder profile for the info sheet

    struct Profile {
        var files = 0, folders = 0, packages = 0
        var oldest: Date?, newest: Date?
        var types: [(ext: String, bytes: Int64, count: Int)] = []
    }

    /// File types, counts and date range of everything below `path` (on demand, second fts pass).
    static func profile(_ path: String) -> Profile {
        var argv: [UnsafeMutablePointer<CChar>?] = [strdup(path), nil]
        defer { free(argv[0]) }
        var r = Profile()
        guard let fts = fts_open(&argv, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else { return r }
        defer { fts_close(fts) }
        var bytes: [String: Int64] = [:], counts: [String: Int] = [:]
        var oldest = Int.max, newest = 0
        var counter = 0
        while let ent = fts_read(fts) {
            counter += 1
            if counter & 0xFFF == 0 && Task.isCancelled { break }
            switch Int32(ent.pointee.fts_info) {
            case FTS_D:
                r.folders += 1
                let n = name(of: ent)
                if n.hasSuffix(".app") || n.hasSuffix(".bundle") || n.hasSuffix(".framework") { r.packages += 1 }
            case FTS_F:
                guard let st = ent.pointee.fts_statp?.pointee else { continue }
                r.files += 1
                let ext = (name(of: ent) as NSString).pathExtension.lowercased()
                let key = ext.isEmpty ? "ohne Endung" : "." + ext
                bytes[key, default: 0] += Int64(st.st_blocks) * 512
                counts[key, default: 0] += 1
                oldest = min(oldest, st.st_mtimespec.tv_sec)
                newest = max(newest, st.st_mtimespec.tv_sec)
            default:
                break
            }
        }
        if r.files > 0 {
            r.oldest = Date(timeIntervalSince1970: TimeInterval(oldest))
            r.newest = Date(timeIntervalSince1970: TimeInterval(newest))
        }
        r.folders = max(0, r.folders - 1)
        r.types = bytes.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value, counts[$0.key] ?? 0) }
        return r
    }
}
