import Foundation

@testable import StorageManager

/// Builds scanned trees by hand, with made-up names and no disk access.
enum TestTree {
    /// Big enough to be listed by name; smaller ones are folded into one row.
    static let big = ScanLimits.smallestListedBytes * 3
    static let small = ScanLimits.smallestListedBytes / 2

    /// A folder holding one file of `fileBytes` and whatever `contents` adds, already added to its
    /// parent. Under the virtual root it becomes a scan root.
    @discardableResult
    static func folder(
        _ name: String, in parent: Node, fileBytes: Int64 = big, contents: (Node) -> Void = { _ in }
    ) -> Node {
        let folder = Node(name: name, parent: parent)
        folder.addFile(fileBytes) { "file.bin" }
        contents(folder)
        folder.finish()
        if parent.isVirtual { folder.attach(to: parent) } else { parent.adopt(folder) }
        return folder
    }

    /// The home folder with Downloads, Library/Caches, Projects (which no category names) and the
    /// folders `also` names, under a virtual root.
    static func home(also names: [String] = []) -> Node {
        let root = Node.virtualRoot()
        folder(Paths.home, in: root) { home in
            folder("Downloads", in: home)
            folder("Library", in: home) { library in folder("Caches", in: library) }
            folder("Projects", in: home)
            for name in names { folder(name, in: home) }
        }
        return root
    }

    /// Each folder inside the one before, all holding one file of `fileBytes`.
    static func chain(_ names: ArraySlice<String>, in parent: Node, fileBytes: Int64) {
        guard let name = names.first else { return }
        folder(name, in: parent, fileBytes: fileBytes) { inner in
            chain(names.dropFirst(), in: inner, fileBytes: fileBytes)
        }
    }

    static func volume(totalBytes: Int64, freeBytes: Int64, availableBytes: Int64)
        -> VolumeInformation
    {
        VolumeInformation(
            path: "/", name: "Disk", totalBytes: totalBytes, freeBytes: freeBytes,
            availableBytes: availableBytes, isInternal: true, isRoot: true)
    }
}
