import Foundation

/// Measures a folder in one fts pass and returns the folder tree.
enum ScanService {
    struct Progress {
        var files = 0
        var bytes: Int64 = 0
        static func + (a: Progress, b: Progress) -> Progress { Progress(files: a.files + b.files, bytes: a.bytes + b.bytes) }
    }

    struct Result {
        let root: Node
        let unreadable: Int
    }

    /// Roots measured by "Rescan": the default areas plus the folders from the settings, without duplicates
    /// and without folders that lie inside another root (nothing counts twice).
    static func defaultRoots() -> [String] {
        let all = (Paths.defaultScanRoots + AppSettings.extraFolders).map(Paths.real).filter(Paths.exists)
        return all.enumerated().filter { i, p in
            all.firstIndex(of: p) == i && !all.contains { $0 != p && p.hasPrefix($0 + "/") }
        }.map(\.element)
    }

    /// Runs on the caller's thread; call it from a low-priority task. Nil when cancelled.
    static func scan(_ path: String, progress: (Progress) -> Void) -> Result? {
        var builder = TreeBuilder()
        var unreadable = 0
        var counter = 0
        var lastReport = Date()

        let finished = FTS.walk(path) { ent in
            counter += 1
            if counter & ScanConfig.cancelCheckMask == 0 {
                if Task.isCancelled { return false }
                if Date().timeIntervalSince(lastReport) > ScanConfig.progressInterval {
                    progress(builder.progress)
                    lastReport = Date()
                }
            }
            switch FTS.info(ent) {
            case FTS_D:
                builder.enter(builder.root == nil ? path : FTS.name(ent))
            case FTS_DP:
                builder.leave()
            case FTS_DNR:  // an unreadable folder arrives as FTS_D first and as FTS_DNR instead of FTS_DP
                unreadable += 1
                builder.leave()
            case FTS_F, FTS_SL, FTS_SLNONE, FTS_DEFAULT:
                if let st = ent.pointee.fts_statp?.pointee { builder.addFile(st) { FTS.name(ent) } }
            case FTS_ERR, FTS_NS:
                unreadable += 1
            default:
                break
            }
            return true
        }
        guard finished, let root = builder.root else { return nil }
        progress(builder.progress)
        return Result(root: root, unreadable: unreadable)
    }
}

/// Builds the folder tree while fts walks the disk.
private struct TreeBuilder {
    private var stack: [Node] = []
    private var seenLinks = Set<UInt64>()  // hard-linked files count once, like du
    private(set) var root: Node?
    private(set) var progress = ScanService.Progress()

    mutating func enter(_ name: String) {
        let node = Node(name: name, parent: stack.last)
        if root == nil { root = node }
        stack.append(node)
    }

    mutating func leave() {
        guard let node = stack.popLast() else { return }
        node.finish()
        stack.last?.adopt(node)
    }

    mutating func addFile(_ st: stat, name: () -> String) {
        guard let dir = stack.last else { return }
        if st.st_nlink > 1 && !seenLinks.insert(UInt64(st.st_ino)).inserted { return }
        let size = FTS.allocated(st)
        dir.addFile(size, name: name)
        progress.files += 1
        progress.bytes += size
    }
}
