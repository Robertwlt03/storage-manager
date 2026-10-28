import AppKit
import Foundation

/// A file or folder with its size in bytes.
struct Entry: Identifiable {
    let url: URL
    let bytes: Int64
    let isFolder: Bool
    let symbol: String  // SF Symbol for the row
    var id: String { url.path }

    init(url: URL, bytes: Int64) {
        self.url = url
        self.bytes = bytes
        let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        isFolder = v?.isDirectory == true && v?.isSymbolicLink != true
        if v?.isSymbolicLink == true { symbol = "arrow.turn.down.right" }
        else if !isFolder { symbol = "doc" }
        else {
            switch url.pathExtension {
            case "app": symbol = "app"
            case "bundle", "framework", "photoslibrary": symbol = "shippingbox"
            default: symbol = "folder"
            }
        }
    }
}

enum Disk {
    static let home = FileManager.default.homeDirectoryForCurrentUser

    /// Per-user area under /private/var/folders/… with the subfolders T, C, X and 0.
    static let tempArea: URL = {
        var buf = [CChar](repeating: 0, count: Int(PATH_MAX))
        confstr(_CS_DARWIN_USER_TEMP_DIR, &buf, buf.count)
        return real((String(cString: buf) as NSString).deletingLastPathComponent)
    }()

    static var chromeClones: URL { tempArea.appendingPathComponent("X/com.google.Chrome.code_sign_clone") }

    static var overviewAreas: [URL] {
        let h = home.path
        let paths = [h, "\(h)/Library", "\(h)/Library/Application Support", "\(h)/Library/Containers", "\(h)/Library/Caches",
                     "\(h)/Downloads", "\(h)/Documents", "\(h)/Applications", "/Applications", "/Library", "/opt"]
        return paths.filter { FileManager.default.fileExists(atPath: $0) }.map { URL(fileURLWithPath: $0) } + [tempArea]
    }

    /// Resolves symlinks like `pwd -P` (URL.resolvingSymlinksInPath would drop the /private prefix).
    static func real(_ path: String) -> URL {
        guard let r = realpath(path, nil) else { return URL(fileURLWithPath: path) }
        defer { free(r) }
        return URL(fileURLWithPath: String(cString: r))
    }

    static func display(_ url: URL) -> String {
        url.path.hasPrefix(home.path) ? "~" + url.path.dropFirst(home.path.count) : url.path
    }

    static func bytes(_ b: Int64) -> String { ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }

    // MARK: Measuring

    static func run(_ tool: String, _ args: [String]) async -> String {
        await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: tool)
            p.arguments = args
            let out = Pipe()
            p.standardOutput = out
            p.standardError = FileHandle.nullDevice
            do { try p.run() } catch { return "" }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return String(decoding: data, as: UTF8.self)
        }.value
    }

    /// Size on disk like `du -sk` (APFS clones count in full).
    static func size(_ url: URL) async -> Int64 {
        let out = await run("/usr/bin/du", ["-sk", url.path])
        return (Int64(out.prefix { $0 != "\t" }) ?? 0) * 1024
    }

    /// Everything directly inside `dir`, biggest first, plus the folder total.
    static func children(_ dir: URL) async -> (total: Int64, items: [Entry]) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        guard !names.isEmpty else { return (0, []) }
        // One du call for all entries, like `du -sk dir/* dir/.*` in the prototype.
        let out = await run("/usr/bin/du", ["-sk"] + names.map { dir.appendingPathComponent($0).path })
        let items = out.split(separator: "\n").compactMap { line -> Entry? in
            guard let tab = line.firstIndex(of: "\t"), let kb = Int64(line[..<tab]) else { return nil }
            return Entry(url: URL(fileURLWithPath: String(line[line.index(after: tab)...])), bytes: kb * 1024)
        }
        return (items.reduce(0) { $0 + $1.bytes }, items.sorted { $0.bytes > $1.bytes })
    }

    struct Volume {
        let total: Int64
        let free: Int64
        var used: Int64 { total - free }
        var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
    }

    static func volume() -> Volume {
        let a = try? FileManager.default.attributesOfFileSystem(forPath: "/System/Volumes/Data")
        return Volume(total: (a?[.systemSize] as? NSNumber)?.int64Value ?? 0,
                      free: (a?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0)
    }

    static func snapshotCount() async -> Int {
        await run("/usr/bin/tmutil", ["listlocalsnapshots", "/"]).split(separator: "\n").filter { $0.contains("com.apple") }.count
    }

    // MARK: Folder details

    struct FolderDetails {
        var files = 0, dirs = 0, apps = 0
        var oldest: Date?, newest: Date?
        var types: [(ext: String, bytes: Int64, count: Int)] = []
    }

    static func details(_ dir: URL) async -> FolderDetails {
        await Task.detached { detailsSync(dir) }.value
    }

    private static func detailsSync(_ dir: URL) -> FolderDetails {
        var d = FolderDetails()
        var bytes: [String: Int64] = [:], counts: [String: Int] = [:]
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: keys, errorHandler: { _, _ in true })
        else { return d }
        for case let url as URL in e {
            let v = try? url.resourceValues(forKeys: Set(keys))
            if v?.isDirectory == true {
                d.dirs += 1
                if url.pathExtension == "app" || url.lastPathComponent.hasSuffix(".app.bundle") { d.apps += 1 }
                continue
            }
            d.files += 1
            let ext = url.pathExtension.isEmpty ? "ohne Endung" : "." + url.pathExtension.lowercased()
            bytes[ext, default: 0] += Int64(v?.fileSize ?? 0)
            counts[ext, default: 0] += 1
            if let m = v?.contentModificationDate {
                d.oldest = min(d.oldest ?? m, m)
                d.newest = max(d.newest ?? m, m)
            }
        }
        d.types = bytes.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value, counts[$0.key] ?? 0) }
        return d
    }

    // MARK: Large files

    static func bigFiles(in dir: URL, minMB: Int) async -> [Entry] {
        let out = await run("/usr/bin/find", [dir.path, "-xdev", "-type", "f", "-size", "+\(minMB)M", "-print0"])
        return out.split(separator: "\0").compactMap { p -> Entry? in
            let path = String(p)
            guard let size = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? NSNumber else { return nil }
            return Entry(url: URL(fileURLWithPath: path), bytes: size.int64Value)
        }.sorted { $0.bytes > $1.bytes }.prefix(100).map { $0 }
    }

    // MARK: Chrome code-signature copies

    struct ChromeInfo {
        var count = 0, apps = 0
        var bytes: Int64 = 0
        var installed: String?
        var versions: [(version: String, count: Int)] = []
        var days: [(day: String, count: Int)] = []
    }

    static var chromeRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").isEmpty
    }

    static func version(of app: URL) -> String? {
        NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))?["CFBundleShortVersionString"] as? String
    }

    /// nil when the folder does not exist.
    static func chromeInfo() async -> ChromeInfo? {
        let root = chromeClones
        guard FileManager.default.fileExists(atPath: root.path) else { return nil }
        async let bytes = size(root)
        var info = await Task.detached { () -> ChromeInfo in
            let fm = FileManager.default
            var i = ChromeInfo()
            i.installed = version(of: URL(fileURLWithPath: "/Applications/Google Chrome.app"))
            var versions: [String: Int] = [:], days: [String: Int] = [:]
            let iso = DateFormatter()
            iso.dateFormat = "yyyy-MM-dd"
            let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
            for dir in (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: Array(keys))) ?? [] {
                let v = try? dir.resourceValues(forKeys: keys)
                guard v?.isDirectory == true else { continue }
                i.count += 1
                if let date = v?.contentModificationDate { days[iso.string(from: date), default: 0] += 1 }
                for name in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
                where name.hasSuffix(".app") || name.hasSuffix(".app.bundle") {
                    i.apps += 1
                    versions[version(of: dir.appendingPathComponent(name)) ?? "unbekannt", default: 0] += 1
                }
            }
            i.versions = versions.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
            i.days = days.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
            return i
        }.value
        info.bytes = await bytes
        return info
    }

    /// Deletes all copies and returns how much free space really grew.
    static func deleteChromeClones() async throws -> Int64 {
        let before = volume().free
        try await Task.detached { try FileManager.default.removeItem(at: chromeClones) }.value
        try? await Task.sleep(for: .seconds(2))  // APFS reports freed blocks with a short delay
        return volume().free - before
    }
}

extension Disk {
    /// `--selftest`: runs every area on real data and prints only counts and sizes, never names.
    static func selfTest() async {
        let v = volume()
        assert(v.total > 0 && v.free > 0)
        print("Volume: \(bytes(v.used)) belegt von \(bytes(v.total)), \(bytes(v.free)) frei, Schnappschüsse \(await snapshotCount())")

        var areaSizes: [Int64] = []
        for url in overviewAreas { areaSizes.append(await size(url)) }
        print("Überblick: \(areaSizes.count) Bereiche, \(areaSizes.filter { $0 > 0 }.count) mit Größe > 0, größter \(bytes(areaSizes.max() ?? 0))")

        for part in ["T", "C", "X", "0"] {
            print("Temp \(part): \(bytes(await size(tempArea.appendingPathComponent(part))))")
        }
        let x = await children(tempArea.appendingPathComponent("X"))
        print("Temp X: \(x.items.count) Einträge, gesamt \(bytes(x.total))")

        let h = await children(home)
        assert(h.total > 0 && !h.items.isEmpty && zip(h.items, h.items.dropFirst()).allSatisfy { $0.bytes >= $1.bytes })
        print("Explorer ~: \(h.items.count) Einträge, \(h.items.filter(\.isFolder).count) Ordner, gesamt \(bytes(h.total))")

        let d = await details(home.appendingPathComponent("Library/Caches"))
        print("Details ~/Library/Caches: \(d.files) Dateien, \(d.dirs) Ordner, \(d.apps) Apps, \(d.types.count) Dateitypen")

        let big = await bigFiles(in: home, minMB: 500)
        assert(big.allSatisfy { $0.bytes > 500 * 1_048_576 })
        print("Große Dateien ab 500 MB in ~: \(big.count) Treffer, größte \(bytes(big.first?.bytes ?? 0))")

        if let c = await chromeInfo() {
            print("Chrome-Kopien: \(c.count) Ordner, \(c.apps) Apps, gezählt \(bytes(c.bytes)), \(c.versions.count) Versionen, \(c.days.count) Tage, installiert \(c.installed ?? "-"), läuft \(chromeRunning)")
            for v in c.versions { print("  \(v.count) × \(v.version)\(v.version == c.installed ? " (aktuell)" : "")") }
        } else {
            print("Chrome-Kopien: keine")
        }
    }
}
