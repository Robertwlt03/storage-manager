import Foundation

/// Measures a folder in one fts pass and returns the folder tree.
nonisolated enum ScanService {
    struct Progress {
        var files = 0
        var bytes: Int64 = 0
        static func + (left: Progress, right: Progress) -> Progress {
            Progress(files: left.files + right.files, bytes: left.bytes + right.bytes)
        }
    }

    struct Result {
        let root: Node
        let unreadable: Int
    }

    /// Roots measured by "Rescan": the default areas plus the folders from the settings, without
    /// duplicates and without folders that lie inside another root (nothing counts twice).
    @MainActor static func defaultRoots() -> [String] {
        let wantedFolders = Paths.defaultScanRoots + AppSettings.extraFolders
        let existingFolders = wantedFolders.map(Paths.withoutSymlinks).filter(Paths.exists)

        func liesInsideAnother(_ folder: String) -> Bool {
            existingFolders.contains { other in other != folder && folder.hasPrefix(other + "/") }
        }
        return existingFolders.enumerated()
            .filter { index, folder in
                existingFolders.firstIndex(of: folder) == index && !liesInsideAnother(folder)
            }
            .map(\.element)
    }

    /// Runs on the caller's thread; call it from a low-priority task. Nil when cancelled.
    static func scan(_ path: String, progress reportProgress: (Progress) -> Void) -> Result? {
        var builder = TreeBuilder()
        var visitedEntries = 0
        var lastReport = Date()

        let isFinished = FileTreeWalker.walk(path) { entry in
            visitedEntries += 1
            if visitedEntries & ScanLimits.cancelCheckMask == 0 {
                if Task.isCancelled { return false }
                if Date().timeIntervalSince(lastReport) > ScanLimits.progressInterval {
                    reportProgress(builder.progress)
                    lastReport = Date()
                }
            }
            builder.add(entry, scanRoot: path)
            return true
        }
        guard isFinished, let root = builder.root else { return nil }
        reportProgress(builder.progress)
        return Result(root: root, unreadable: builder.unreadable)
    }
}

/// Builds the folder tree while fts walks the disk.
private nonisolated struct TreeBuilder {
    private var openFolders: [Node] = []
    /// Hard-linked files count once, like du.
    private var seenLinkedFiles = Set<UInt64>()
    private(set) var root: Node?
    private(set) var progress = ScanService.Progress()
    private(set) var unreadable = 0

    mutating func add(_ entry: UnsafeMutablePointer<FTSENT>, scanRoot: String) {
        switch FileTreeWalker.kind(of: entry) {
        case FTS_D:
            enter(root == nil ? scanRoot : FileTreeWalker.name(of: entry))
        case FTS_DP:
            leave()
        // An unreadable folder arrives as FTS_D first and as FTS_DNR instead of FTS_DP.
        case FTS_DNR:
            unreadable += 1
            leave()
        case FTS_F, FTS_SL, FTS_SLNONE, FTS_DEFAULT:
            if let fileStatus = entry.pointee.fts_statp?.pointee {
                addFile(fileStatus) { FileTreeWalker.name(of: entry) }
            }
        case FTS_ERR, FTS_NS:
            unreadable += 1
        default:
            break
        }
    }

    private mutating func enter(_ name: String) {
        let node = Node(name: name, parent: openFolders.last)
        if root == nil { root = node }
        openFolders.append(node)
    }

    private mutating func leave() {
        guard let node = openFolders.popLast() else { return }
        node.finish()
        openFolders.last?.adopt(node)
    }

    private mutating func addFile(_ fileStatus: stat, name: () -> String) {
        guard let folder = openFolders.last else { return }
        let isHardLinked = fileStatus.st_nlink > 1
        if isHardLinked && !seenLinkedFiles.insert(UInt64(fileStatus.st_ino)).inserted { return }
        let size = FileTreeWalker.allocatedBytes(fileStatus)
        folder.addFile(size, name: name)
        progress.files += 1
        progress.bytes += size
    }
}
