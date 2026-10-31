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
        let unreadableCount: Int
    }

    /// Roots measured by "Rescan": the default areas plus the folders from the settings, without
    /// duplicates and without folders that lie inside another root (nothing counts twice).
    @MainActor static func defaultRoots() -> [String] {
        let wantedFolders = Paths.defaultScanRoots + AppSettings.extraFolders
        let existingFolders = wantedFolders.map(Paths.withoutSymlinks).filter(Paths.exists)
        let excluded = excludedFolders()
        return withoutDuplicatesOrNesting(existingFolders)
            .filter { folder in !liesIn(folder, anyOf: excluded) }
    }

    /// The folders from the settings that no scan measures, as the walk sees their paths.
    @MainActor static func excludedFolders() -> Set<String> {
        Set(AppSettings.excludedFolders.map(Paths.withoutSymlinks))
    }

    static func liesIn(_ folder: String, anyOf others: Set<String>) -> Bool {
        others.contains { other in folder == other || folder.hasPrefix(other + "/") }
    }

    /// Keeps each folder once, in its order, and drops folders that lie inside another one.
    static func withoutDuplicatesOrNesting(_ folders: [String]) -> [String] {
        func liesInsideAnother(_ folder: String) -> Bool {
            folders.contains { other in other != folder && folder.hasPrefix(other + "/") }
        }
        return folders.enumerated()
            .filter { index, folder in
                folders.firstIndex(of: folder) == index && !liesInsideAnother(folder)
            }
            .map(\.element)
    }

    /// Runs on the caller's thread; call it from a low-priority task. Nil when canceled.
    static func scan(
        _ path: String, excluding excluded: Set<String> = [],
        progress reportProgress: (Progress) -> Void
    ) -> Result? {
        var builder = TreeBuilder()
        var visitedEntries = 0
        var lastReport = Date()

        let isComplete = FileTreeWalker.walk(path, excluding: excluded) { entry in
            visitedEntries += 1
            let isCheckpoint = visitedEntries & ScanLimits.cancelCheckMask == 0
            if isCheckpoint && Task.isCancelled { return false }
            if isCheckpoint && Date().timeIntervalSince(lastReport) > ScanLimits.progressInterval {
                reportProgress(builder.progress)
                lastReport = Date()
            }
            builder.add(entry, scanRoot: path)
            return true
        }
        if Task.isCancelled { return nil }
        if !isComplete { builder.closeAfterError() }
        guard let root = builder.root else { return nil }
        reportProgress(builder.progress)
        return Result(root: root, unreadableCount: builder.unreadableCount)
    }
}

/// Builds the folder tree while fts walks the disk.
private nonisolated struct TreeBuilder {
    private var openFolders: [Node] = []
    /// Hard-linked files count once, like du.
    private var seenLinkedFiles = Set<UInt64>()
    private(set) var root: Node?
    private(set) var progress = ScanService.Progress()
    private(set) var unreadableCount = 0

    mutating func add(_ entry: UnsafeMutablePointer<FTSENT>, scanRoot: String) {
        switch FileTreeWalker.kind(of: entry) {
        case FTS_D:
            enter(root == nil ? scanRoot : FileTreeWalker.name(of: entry))
        case FTS_DP:
            leave()
        // An unreadable folder arrives as FTS_D first and as FTS_DNR instead of FTS_DP.
        case FTS_DNR:
            unreadableCount += 1
            leave()
        case FTS_F, FTS_SL, FTS_SLNONE, FTS_DEFAULT:
            if let fileStatus = entry.pointee.fts_statp?.pointee {
                addFile(fileStatus) { FileTreeWalker.name(of: entry) }
            }
        case FTS_ERR, FTS_NS:
            unreadableCount += 1
        default:
            break
        }
    }

    /// An fts error ends the walk with folders still open; closing them keeps what was measured.
    mutating func closeAfterError() {
        unreadableCount += 1
        while !openFolders.isEmpty { leave() }
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
