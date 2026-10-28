import AppKit
import SwiftUI

enum Paths {
    static let home = FileManager.default.homeDirectoryForCurrentUser.path

    /// Per-user area under /private/var/folders/… with the subfolders T, C, X and 0.
    static let tempArea: String = {
        var buf = [CChar](repeating: 0, count: Int(PATH_MAX))
        confstr(_CS_DARWIN_USER_TEMP_DIR, &buf, buf.count)
        return real((String(cString: buf) as NSString).deletingLastPathComponent)
    }()

    /// Resolves symlinks like `pwd -P` (URL.resolvingSymlinksInPath would drop the /private prefix).
    static func real(_ path: String) -> String {
        guard let r = realpath(path, nil) else { return path }
        defer { free(r) }
        return String(cString: r)
    }

    static func display(_ path: String) -> String {
        if path == tempArea { return "Temporärer Systembereich" }
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    static func exists(_ path: String) -> Bool { FileManager.default.fileExists(atPath: path) }
}

enum Fmt {
    static func bytes(_ b: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: b, countStyle: UserDefaults.standard.bool(forKey: Prefs.binaryUnits) ? .binary : .file)
    }

    static func count(_ n: Int) -> String { n.formatted(.number) }
    static func copies(_ n: Int) -> String { n == 1 ? "1 Kopie" : "\(count(n)) Kopien" }
}

// MARK: Volumes

struct VolumeInfo: Identifiable, Hashable {
    let path: String
    let name: String
    let format: String
    let total, free, available: Int64  // available = free + what macOS can purge on demand
    let isInternal, isRoot: Bool
    var id: String { path }
    var purgeable: Int64 { max(0, available - free) }
    var used: Int64 { max(0, total - free) }
    var symbol: String { isInternal ? "internaldrive" : "externaldrive" }

    static func all() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeLocalizedFormatDescriptionKey, .volumeTotalCapacityKey,
                                      .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
                                      .volumeIsInternalKey, .volumeIsRootFileSystemKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url in
            guard let v = try? url.resourceValues(forKeys: Set(keys)), let total = v.volumeTotalCapacity, total > 0 else { return nil }
            let free = Int64(v.volumeAvailableCapacity ?? 0)
            return VolumeInfo(path: url.path, name: v.volumeName ?? url.lastPathComponent,
                              format: v.volumeLocalizedFormatDescription ?? "", total: Int64(total), free: free,
                              available: max(free, v.volumeAvailableCapacityForImportantUsage ?? 0),
                              isInternal: v.volumeIsInternal ?? false, isRoot: v.volumeIsRootFileSystem ?? false)
        }
        .sorted { ($0.isRoot ? 0 : 1, $0.name) < ($1.isRoot ? 0 : 1, $1.name) }
    }
}

// MARK: Categories

struct Category: Identifiable {
    let title: String
    let symbol: String
    let colorIndex: Int
    var bytes: Int64 = 0
    var node: Node?  // where a click leads, if anywhere
    var id: String { title }
}

enum Categories {
    /// Rules match whole folders; the most specific match wins. Missing folders simply stay empty,
    /// so the same list works on every Mac.
    static let rules: [(title: String, symbol: String, paths: [String])] = [
        ("Programme", "square.grid.2x2", ["/Applications", "~/Applications"]),
        ("Dokumente & Schreibtisch", "doc.text", ["~/Documents", "~/Desktop"]),
        ("Downloads", "arrow.down.circle", ["~/Downloads"]),
        ("Fotos, Musik & Filme", "photo.on.rectangle", ["~/Pictures", "~/Music", "~/Movies"]),
        ("iCloud Drive", "icloud", ["~/Library/Mobile Documents"]),
        ("Mail & Nachrichten", "envelope", ["~/Library/Mail", "~/Library/Messages"]),
        ("Entwicklung", "hammer", ["~/Library/Developer", "~/.npm", "~/.cache", "~/.docker", "~/.gradle", "~/.m2", "~/.cargo",
                                   "~/.rustup", "~/go", "~/.pub-cache", "~/.composer", "~/.local",
                                   "~/Library/Containers/com.docker.docker", "/opt", "/usr/local"]),
        ("Caches", "archivebox", ["~/Library/Caches"]),
        ("App-Daten", "shippingbox", ["~/Library/Application Support", "~/Library/Containers", "~/Library/Group Containers"]),
        ("Papierkorb", "trash", ["~/.Trash"]),
        ("Temporäre Dateien", "hourglass", [Paths.tempArea]),
        ("Weitere Benutzerdaten", "person.crop.circle", [Paths.home]),
        ("Library (systemweit)", "gearshape", ["/Library"]),
        ("Weitere Ordner", "folder", []),
        ("Von macOS löschbar", "arrow.3.trianglepath", []),
        ("System & Sonstiges", "internaldrive", []),
    ]

    static func compute(root: Node, volume: VolumeInfo?) -> [Category] {
        var byPath: [String: Int] = [:]
        for (i, r) in rules.enumerated() {
            for p in r.paths { byPath[p.hasPrefix("~") ? Paths.home + p.dropFirst() : p] = i }
        }
        var cats = rules.enumerated().map { Category(title: $1.title, symbol: $1.symbol, colorIndex: $0) }
        let other = rules.firstIndex { $0.title == "Weitere Ordner" }!

        func walk(_ n: Node, _ path: String, _ inherited: Int) {
            let hit = byPath[path]
            let c = hit ?? inherited
            if hit != nil && cats[c].node == nil { cats[c].node = n }
            var own = n.bytes
            for ch in n.children {
                walk(ch, path + "/" + ch.name, c)
                own -= ch.bytes
            }
            cats[c].bytes += own
        }
        for r in root.children { walk(r, r.name, other) }

        if let v = volume {
            let scanned = cats.reduce(0) { $0 + $1.bytes }
            cats[rules.count - 2].bytes = v.purgeable
            // Clones count in full while scanning, so this can go below zero; then it stays empty.
            cats[rules.count - 1].bytes = max(0, v.used - v.purgeable - scanned)
        }
        return cats.filter { $0.bytes > 0 }.sorted { $0.bytes > $1.bytes }
    }
}

// MARK: Code-signature copies

/// Folders like `X/com.google.Chrome.code_sign_clone` that macOS fills with copies of an app while checking its signature.
struct CopyGroup: Identifiable {
    let node: Node
    var id: String { node.name }
    var bundleID: String { String(node.name.dropLast(".code_sign_clone".count)) }
    var appURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }
    var appName: String { appURL.map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID }
    var installedVersion: String? { appURL.flatMap { Bundle(url: $0)?.infoDictionary?["CFBundleShortVersionString"] as? String } }
    var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty }

    struct Details { var count = 0; var versions: [(String, Int)] = []; var days: [(Date, Int)] = [] }

    /// Reads one Info.plist and one date per copy, on demand.
    func details() -> Details {
        let fm = FileManager.default
        var d = Details()
        var versions: [String: Int] = [:], days: [Date: Int] = [:]
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
        for dir in (try? fm.contentsOfDirectory(at: node.url, includingPropertiesForKeys: Array(keys))) ?? [] {
            let v = try? dir.resourceValues(forKeys: keys)
            guard v?.isDirectory == true else { continue }
            d.count += 1
            if let date = v?.contentModificationDate { days[Calendar.current.startOfDay(for: date), default: 0] += 1 }
            let app = (try? fm.contentsOfDirectory(atPath: dir.path))?.first { $0.hasSuffix(".app") || $0.hasSuffix(".app.bundle") }
            let version = app.flatMap {
                NSDictionary(contentsOfFile: dir.path + "/" + $0 + "/Contents/Info.plist")?["CFBundleShortVersionString"] as? String
            }
            versions[version ?? "unbekannt", default: 0] += 1
        }
        d.versions = versions.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
        d.days = days.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        return d
    }
}

// MARK: App model

enum Pane: Hashable {
    case overview, explorer, largeFiles, temp, copies
    case volume(String)
}

@MainActor @Observable final class AppModel {
    var pane: Pane? = .overview
    var explorerPath: [Node] = []
    let root = Node(name: "", parent: nil)
    var revision = 0  // bumped whenever the tree changes; views read it to refresh
    var scanning = false
    var progress = Scanner.Progress()
    var lastScan: Date?
    var unreadable = 0
    var volumes = VolumeInfo.all()
    var categories: [Category] = []
    private var task: Task<Void, Never>?

    var startupVolume: VolumeInfo? { volumes.first { $0.isRoot } }

    var defaultRoots: [String] {
        let extra = UserDefaults.standard.string(forKey: Prefs.extraFolders)?.split(separator: "\n").map(String.init) ?? []
        let all = ([Paths.home, "/Applications", "/Library", "/opt", "/usr/local", Paths.tempArea] + extra)
            .map(Paths.real).filter(Paths.exists)
        // Drop folders that lie inside another root, so nothing counts twice.
        return all.enumerated().filter { i, p in
            !all.contains { $0 != p && p.hasPrefix($0 + "/") } && all.firstIndex(of: p) == i
        }.map(\.element)
    }

    func autoScanIfWanted() {
        let d = UserDefaults.standard
        guard d.bool(forKey: Prefs.autoScan), lastScan == nil, !scanning else { return }
        if d.bool(forKey: Prefs.pauseOnLowPower) && ProcessInfo.processInfo.isLowPowerModeEnabled { return }
        scan()
    }

    /// Measures `paths` one after another; with `reset` the tree starts empty.
    func scan(_ paths: [String]? = nil, reset: Bool = true) {
        task?.cancel()
        if reset {
            root.children = []
            root.bytes = 0
            root.fileCount = 0
            unreadable = 0
            explorerPath = []
        }
        let todo = paths ?? defaultRoots
        let priority: TaskPriority = UserDefaults.standard.bool(forKey: Prefs.eco) ? .background : .utility
        scanning = true
        progress = .init(files: root.fileCount, bytes: root.bytes)
        task = Task {
            for path in todo {
                root.children.first { $0.name == path }?.detach()
                let base = progress
                let inner = Task.detached(priority: priority) { () -> (Node?, Int) in
                    var unreadable = 0
                    let node = Scanner.scan(path, unreadable: &unreadable) { p in
                        Task { @MainActor in self.progress = .init(files: base.files + p.files, bytes: base.bytes + p.bytes) }
                    }
                    return (node, unreadable)
                }
                let (node, unreadable) = await withTaskCancellationHandler { await inner.value } onCancel: { inner.cancel() }
                guard !Task.isCancelled, let node else { break }
                node.attach(to: root)
                root.children.sort { $0.bytes > $1.bytes }
                self.unreadable += unreadable
                progress = .init(files: root.fileCount, bytes: root.bytes)
                treeChanged()
            }
            scanning = false
            if !Task.isCancelled { lastScan = Date() }
            treeChanged()
        }
    }

    func cancelScan() {
        task?.cancel()
        scanning = false
    }

    func treeChanged() {
        volumes = VolumeInfo.all()
        // The remainder ("System & Sonstiges") only makes sense once every area is measured.
        categories = Categories.compute(root: root, volume: scanning ? nil : startupVolume)
        revision += 1
    }

    func node(at path: String) -> Node? {
        for r in root.children where path == r.name || path.hasPrefix(r.name + "/") {
            var n = r
            for c in path.dropFirst(r.name.count).split(separator: "/") {
                guard let next = n.child(named: String(c)) else { return nil }
                n = next
            }
            return n
        }
        return nil
    }

    func open(_ node: Node) {
        var chain: [Node] = []
        var n: Node? = node
        while let x = n, !x.isVirtual {
            chain.insert(x, at: 0)
            n = x.parent
        }
        explorerPath = chain
        pane = .explorer
    }

    func files(atLeast min: Int64) -> [FileItem] {
        var out: [FileItem] = []
        func walk(_ n: Node) {
            out += n.files.filter { $0.bytes >= min }
            n.children.forEach(walk)
        }
        walk(root)
        return out.sorted { $0.bytes > $1.bytes }
    }

    var copyGroups: [CopyGroup] {
        _ = revision
        return node(at: Paths.tempArea + "/X")?.children.filter { $0.name.hasSuffix(".code_sign_clone") }.map(CopyGroup.init) ?? []
    }

    /// Deletes all copies of one app and returns how much free space really grew.
    func delete(_ group: CopyGroup) async throws -> Int64 {
        let before = VolumeInfo.all().first { $0.isRoot }?.free ?? 0
        let url = group.node.url
        try await Task.detached(priority: .utility) { try FileManager.default.removeItem(at: url) }.value
        try? await Task.sleep(for: .seconds(2))  // APFS reports freed blocks with a short delay
        group.node.detach()
        treeChanged()
        return (startupVolume?.free ?? before) - before
    }
}
