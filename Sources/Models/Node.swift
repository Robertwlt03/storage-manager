import Foundation

/// One folder in the scanned tree. Sizes are allocated bytes like `du` (APFS clones count in full).
/// A scan builds the tree in the background and hands it over whole; from then on only the main
/// actor changes it. That hand-over is why it may cross threads (`@unchecked Sendable`).
nonisolated final class Node: Identifiable, Hashable, @unchecked Sendable {
    let name: String
    private(set) weak var parent: Node?
    private(set) var bytes: Int64 = 0
    private(set) var fileCount = 0
    /// Folders of at least `ScanLimits.smallestListedBytes`, biggest first.
    private(set) var children: [Node] = []
    /// Files of at least `ScanLimits.smallestListedBytes`, biggest first.
    private(set) var files: [FileItem] = []
    /// Smaller files and folders directly inside, folded into one row.
    private(set) var restBytes: Int64 = 0
    private(set) var restCount = 0
    /// The heading of a group of folders that is no folder on disk, such as a category's.
    private(set) var title: String?

    init(name: String, parent: Node?) {
        self.name = name
        self.parent = parent
    }

    static func virtualRoot() -> Node { Node(name: "", parent: nil) }

    var isVirtual: Bool { parent == nil && name.isEmpty }
    var isGroup: Bool { title != nil }
    /// The root that lists the measured areas, not a category's group of folders.
    var listsAreas: Bool { isVirtual && !isGroup }
    var isScanRoot: Bool { parent?.isVirtual == true }
    /// Scan roots carry their absolute path as name.
    var path: String {
        guard let parent else { return name }
        return parent.isVirtual ? name : parent.path + "/" + name
    }
    var displayName: String { title ?? (isScanRoot ? Paths.displayName(name) : name) }

    func child(named name: String) -> Node? { children.first { child in child.name == name } }

    /// The chain from the scan root down to this node (for the explorer's navigation path).
    var nodesFromRoot: [Node] {
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
        if size >= ScanLimits.smallestListedBytes {
            files.append(FileItem(path: path + "/" + name(), bytes: size))
        } else {
            restBytes += size
            restCount += 1
        }
    }

    func adopt(_ child: Node) {
        bytes += child.bytes
        fileCount += child.fileCount
        if child.bytes >= ScanLimits.smallestListedBytes {
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

    // MARK: Views of the finished tree

    /// Folders that belong together without one folder on disk, such as a category's, under a
    /// title. The folders keep their own parents, so their paths still lead to the disk.
    static func group(_ title: String, of folders: [Node]) -> Node {
        let group = virtualRoot()
        group.title = title
        for folder in folders { group.adopt(folder) }
        group.finish()
        return group
    }

    /// This folder without the subfolders `keeps` turns down, at any depth, with its size and file
    /// count shrunk to match. The copy keeps this folder's parent, so its path, Finder and the
    /// Trash still reach the real folder; with nothing left out it is this folder itself.
    func portion(keeping keeps: (Node) -> Bool) -> Node {
        let portions = children.filter(keeps).map { child in child.portion(keeping: keeps) }
        let isWhole =
            portions.count == children.count
            && zip(portions, children).allSatisfy { portion, child in portion === child }
        if isWhole { return self }
        let copy = Node(name: name, parent: parent)
        (copy.files, copy.restBytes, copy.restCount) = (files, restBytes, restCount)
        copy.bytes = bytes - children.reduce(0) { total, child in total + child.bytes }
        copy.fileCount = fileCount - children.reduce(0) { total, child in total + child.fileCount }
        for portion in portions { copy.adopt(portion) }
        copy.finish()
        return copy
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
        // A node kept elsewhere, such as a copy group, can no longer change the tree.
        parent = nil
    }

    /// Removes one listed file from this folder and subtracts its size from every folder above.
    func removeFile(_ path: String) {
        guard let index = files.firstIndex(where: { file in file.path == path }) else { return }
        let removed = files.remove(at: index)
        var nextFolder: Node? = self
        while let folder = nextFolder {
            folder.bytes -= removed.bytes
            folder.fileCount -= 1
            nextFolder = folder.parent
        }
    }

    func removeAll() {
        for child in children { child.parent = nil }
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

    /// Whether this very folder is part of the tree below this (virtual) root, not a copy of it.
    func holds(_ node: Node) -> Bool { descendant(at: node.path) === node }

    /// The size of a folder or listed file by absolute path; nil when it was folded or not
    /// scanned.
    func entryBytes(at path: String) -> Int64? {
        if let folder = descendant(at: path) { return folder.bytes }
        let folderPath = (path as NSString).deletingLastPathComponent
        return descendant(at: folderPath)?.files.first { file in file.path == path }?.bytes
    }

    static func == (left: Node, right: Node) -> Bool { left === right }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

nonisolated struct FileItem: Identifiable, Hashable {
    let path: String
    let bytes: Int64
    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
}
