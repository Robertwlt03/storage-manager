import Foundation

/// One row in a folder table or search result: a folder, a file or the folded rest of a folder.
struct Entry: Identifiable {
    enum Kind {
        case folder(Node)
        case file, rest
    }

    let id: String
    let name: String
    let path: String?
    let bytes: Int64
    let itemCount: Int
    let kind: Kind

    var node: Node? { if case .folder(let folderNode) = kind { folderNode } else { nil } }
    var isFolder: Bool { node != nil }

    static func folder(_ node: Node) -> Entry {
        Entry(
            id: node.path, name: node.displayName, path: node.path, bytes: node.bytes,
            itemCount: node.fileCount, kind: .folder(node))
    }

    static func file(_ file: FileItem) -> Entry {
        Entry(
            id: file.path, name: file.name, path: file.path, bytes: file.bytes, itemCount: 1,
            kind: .file)
    }

    static func rest(of node: Node) -> Entry {
        Entry(
            id: node.path + "/\u{0}rest",
            name: TextKey.smallerItems.translated(with: Format.count(node.restCount)), path: nil,
            bytes: node.restBytes, itemCount: node.restCount, kind: .rest)
    }

    /// Everything directly inside a folder.
    static func contents(of node: Node) -> [Entry] {
        let folders = node.children.map(folder)
        let files = node.files.map(file)
        let smallerItems = node.restCount > 0 ? [rest(of: node)] : []
        return folders + files + smallerItems
    }
}

struct VolumeInfo: Identifiable, Hashable {
    let path: String
    let name: String
    let format: String
    /// `availableBytes` is `freeBytes` plus what macOS can purge on demand.
    let totalBytes, freeBytes, availableBytes: Int64
    let isInternal, isRoot: Bool
    var id: String { path }
    var purgeableBytes: Int64 { max(0, availableBytes - freeBytes) }
    var usedBytes: Int64 { max(0, totalBytes - freeBytes) }
    var symbol: String { isInternal ? Symbols.internalDrive : Symbols.externalDrive }
}

struct Category: Identifiable {
    let kind: CategoryKind
    var bytes: Int64 = 0
    var node: Node?  // where a click leads, if anywhere
    var id: CategoryKind { kind }
}

/// Folders like `X/com.google.Chrome.code_sign_clone` that macOS fills with copies of an app while
/// checking it.
struct CopyGroup: Identifiable {
    let node: Node
    let bundleID: String
    let appPath: String?
    let appName: String
    let installedVersion: String?
    var id: String { node.path }
}

struct CopyDetails {
    var copyCount = 0
    var versions: [(version: String, count: Int)] = []
    var days: [(day: Date, count: Int)] = []
}

struct FolderProfile {
    var files = 0, folders = 0, packages = 0
    var oldest: Date?, newest: Date?
    var types: [(fileExtension: String, bytes: Int64, count: Int)] = []
}
