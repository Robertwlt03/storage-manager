import Foundation

/// One row in a folder table or search result: a folder, a file or the folded rest of a folder.
struct Entry: Identifiable {
    enum Kind { case folder(Node), file, rest }

    let id: String
    let name: String
    let path: String?
    let bytes: Int64
    let items: Int
    let kind: Kind

    var node: Node? { if case .folder(let n) = kind { n } else { nil } }
    var isFolder: Bool { node != nil }

    static func folder(_ n: Node) -> Entry {
        Entry(id: n.path, name: n.displayName, path: n.path, bytes: n.bytes, items: n.fileCount, kind: .folder(n))
    }

    static func file(_ f: FileItem) -> Entry {
        Entry(id: f.path, name: f.name, path: f.path, bytes: f.bytes, items: 1, kind: .file)
    }

    static func rest(of n: Node) -> Entry {
        Entry(id: n.path + "/\u{0}rest", name: Loc.smallerItems.f(Fmt.count(n.restCount)), path: nil,
              bytes: n.restBytes, items: n.restCount, kind: .rest)
    }

    /// Everything directly inside a folder.
    static func contents(of n: Node) -> [Entry] {
        n.children.map(folder) + n.files.map(file) + (n.restCount > 0 ? [rest(of: n)] : [])
    }
}

struct VolumeInfo: Identifiable, Hashable {
    let path: String
    let name: String
    let format: String
    let total, free, available: Int64  // available = free + what macOS can purge on demand
    let isInternal, isRoot: Bool
    var id: String { path }
    var purgeable: Int64 { max(0, available - free) }
    var used: Int64 { max(0, total - free) }
    var symbol: String { isInternal ? Symbols.internalDrive : Symbols.externalDrive }
}

struct Category: Identifiable {
    let kind: CategoryKind
    var bytes: Int64 = 0
    var node: Node?  // where a click leads, if anywhere
    var id: CategoryKind { kind }
}

/// Folders like `X/com.google.Chrome.code_sign_clone` that macOS fills with copies of an app while checking it.
struct CopyGroup: Identifiable {
    let node: Node
    let bundleID: String
    let appPath: String?
    let appName: String
    let installedVersion: String?
    var id: String { node.path }
}

struct CopyDetails {
    var count = 0
    var versions: [(version: String, count: Int)] = []
    var days: [(day: Date, count: Int)] = []
}

struct FolderProfile {
    var files = 0, folders = 0, packages = 0
    var oldest: Date?, newest: Date?
    var types: [(ext: String, bytes: Int64, count: Int)] = []
}
