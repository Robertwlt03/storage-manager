import Foundation

/// One folder in the scanned tree. Sizes are allocated bytes like `du` (APFS clones count in full).
final class Node: Identifiable, Hashable {
    let name: String
    private(set) weak var parent: Node?
    private(set) var bytes: Int64 = 0
    private(set) var fileCount = 0
    /// Folders of at least `ScanConfig.keepBytes`, biggest first.
    private(set) var children: [Node] = []
    /// Files of at least `ScanConfig.keepBytes`, biggest first.
    private(set) var files: [FileItem] = []
    /// Smaller files and folders directly inside, folded into one row.
    private(set) var restBytes: Int64 = 0
    private(set) var restCount = 0

    init(name: String, parent: Node?) {
        self.name = name
        self.parent = parent
    }

    static func virtualRoot() -> Node { Node(name: "", parent: nil) }

    var isVirtual: Bool { parent == nil && name.isEmpty }
    var isScanRoot: Bool { parent?.isVirtual == true }
    /// Scan roots carry their absolute path as name.
    var path: String {
        guard let parent else { return name }
        return parent.isVirtual ? name : parent.path + "/" + name
    }
    var displayName: String { isScanRoot ? Paths.display(name) : name }

    func child(named name: String) -> Node? { children.first { child in child.name == name } }

    /// The chain from the scan root down to this node (for the explorer's navigation path).
    var chain: [Node] {
        var chainFromRoot: [Node] = []
        var current: Node? = self
        while let node = current, !node.isVirtual {
            chainFromRoot.insert(node, at: 0)
            current = node.parent
        }
        return chainFromRoot
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
        children.sort { left, right in left.bytes > right.bytes }
        files.sort { left, right in left.bytes > right.bytes }
    }

    // MARK: Changing the finished tree

    func attach(to newParent: Node) {
        parent = newParent
        newParent.children.append(self)
        newParent.bytes += bytes
        newParent.fileCount += fileCount
        newParent.finish()
    }

    /// Removes this folder from the tree and subtracts its size from every ancestor.
    func detach() {
        var nextAncestor = parent
        while let ancestor = nextAncestor {
            ancestor.bytes -= bytes
            ancestor.fileCount -= fileCount
            nextAncestor = ancestor.parent
        }
        parent?.children.removeAll { child in child === self }
    }

    func removeAll() {
        children = []
        bytes = 0
        fileCount = 0
    }

    /// Finds a folder by absolute path inside this (virtual) root.
    func descendant(at path: String) -> Node? {
        for scanRoot in children where path == scanRoot.name || path.hasPrefix(scanRoot.name + "/")
        {
            var node = scanRoot
            for folderName in path.dropFirst(scanRoot.name.count).split(separator: "/") {
                guard let next = node.child(named: String(folderName)) else { return nil }
                node = next
            }
            return node
        }
        return nil
    }

    static func == (left: Node, right: Node) -> Bool { left === right }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

struct FileItem: Identifiable, Hashable {
    let path: String
    let bytes: Int64
    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
    var folder: String { (path as NSString).deletingLastPathComponent }
}
