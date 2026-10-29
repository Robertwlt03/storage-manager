import Foundation

/// One folder in the scanned tree. Sizes are allocated bytes like `du` (APFS clones count in full).
final class Node: Identifiable, Hashable {
    let name: String
    private(set) weak var parent: Node?
    private(set) var bytes: Int64 = 0
    private(set) var fileCount = 0
    private(set) var children: [Node] = []  // folders of at least `ScanConfig.keepBytes`, biggest first
    private(set) var files: [FileItem] = []  // files of at least `ScanConfig.keepBytes`, biggest first
    private(set) var restBytes: Int64 = 0  // smaller files and folders directly inside, folded into one row
    private(set) var restCount = 0

    init(name: String, parent: Node?) {
        self.name = name
        self.parent = parent
    }

    static func virtualRoot() -> Node { Node(name: "", parent: nil) }

    var isVirtual: Bool { parent == nil && name.isEmpty }
    var isScanRoot: Bool { parent?.isVirtual == true }
    /// Scan roots carry their absolute path as name.
    var path: String { parent.map { $0.isVirtual ? name : $0.path + "/" + name } ?? name }
    var displayName: String { isScanRoot ? Paths.display(name) : name }

    func child(named n: String) -> Node? { children.first { $0.name == n } }

    /// The chain from the scan root down to this node (for the explorer's navigation path).
    var chain: [Node] {
        var out: [Node] = []
        var n: Node? = self
        while let x = n, !x.isVirtual {
            out.insert(x, at: 0)
            n = x.parent
        }
        return out
    }

    // MARK: Building (used by ScanService while walking)

    func addFile(_ size: Int64, name: () -> String) {
        bytes += size
        fileCount += 1
        if size >= ScanConfig.keepBytes {
            files.append(FileItem(path: path + "/" + name(), bytes: size))
        } else {
            restBytes += size
            restCount += 1
        }
    }

    func adopt(_ child: Node) {
        bytes += child.bytes
        fileCount += child.fileCount
        if child.bytes >= ScanConfig.keepBytes {
            children.append(child)
        } else {
            restBytes += child.bytes
            restCount += 1
        }
    }

    func finish() {
        children.sort { $0.bytes > $1.bytes }
        files.sort { $0.bytes > $1.bytes }
    }

    // MARK: Changing the finished tree

    func attach(to p: Node) {
        parent = p
        p.children.append(self)
        p.bytes += bytes
        p.fileCount += fileCount
        p.finish()
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

    func removeAll() {
        children = []
        bytes = 0
        fileCount = 0
    }

    /// Finds a folder by absolute path inside this (virtual) root.
    func descendant(at path: String) -> Node? {
        for r in children where path == r.name || path.hasPrefix(r.name + "/") {
            var n = r
            for c in path.dropFirst(r.name.count).split(separator: "/") {
                guard let next = n.child(named: String(c)) else { return nil }
                n = next
            }
            return n
        }
        return nil
    }

    static func == (a: Node, b: Node) -> Bool { a === b }
    func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
}

struct FileItem: Identifiable, Hashable {
    let path: String
    let bytes: Int64
    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
    var folder: String { (path as NSString).deletingLastPathComponent }
}
