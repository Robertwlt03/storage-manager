import Foundation
import Observation

/// App state: what is selected, the scanned tree and everything derived from it.
/// The work itself happens in the services; this class only orchestrates them.
@MainActor @Observable final class AppModel {
    var pane: Pane? = .overview
    var explorerPath: [Node] = []
    var searchText = ""
    var searchScope = SearchScope.all
    var showAccessSheet = false

    let root = Node.virtualRoot()
    private(set) var revision = 0  // bumped whenever the tree changes; views read it to refresh
    private(set) var scanning = false
    private(set) var progress = ScanService.Progress()
    private(set) var lastScan: Date?
    private(set) var unreadable = 0
    private(set) var volumes = VolumeService.all()
    private(set) var categories: [Category] = []
    private(set) var hasFullDiskAccess = PermissionService.hasFullDiskAccess
    private var task: Task<Void, Never>?

    var startupVolume: VolumeInfo? { volumes.first { $0.isRoot } }
    var hasData: Bool { !root.children.isEmpty }
    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }
    var copyGroups: [CopyGroup] {
        _ = revision
        return CopyService.groups(in: root.descendant(at: Paths.tempCopies))
    }

    // MARK: Launch

    /// Asks for Full Disk Access on every launch until it works (one switch instead of many prompts),
    /// then scans if the settings allow it.
    func launch() {
        if let p = AppSettings.launchPane { pane = p }
        refreshAccess()
        if !hasFullDiskAccess && !AppSettings.launchSkipAccess { showAccessSheet = true } else { autoScanIfWanted() }
    }

    func refreshAccess() { hasFullDiskAccess = PermissionService.hasFullDiskAccess }

    func finishAccessSheet() {
        showAccessSheet = false
        autoScanIfWanted()
    }

    private func autoScanIfWanted() {
        guard AppSettings.autoScan, lastScan == nil, !scanning else { return }
        if AppSettings.pauseOnLowPower && ProcessInfo.processInfo.isLowPowerModeEnabled { return }
        scan()
    }

    // MARK: Scanning

    /// Measures `paths` one after another; with `reset` the tree starts empty.
    func scan(_ paths: [String]? = nil, reset: Bool = true) {
        task?.cancel()
        if reset {
            root.removeAll()
            unreadable = 0
            explorerPath = []
        }
        scanning = true
        progress = .init(files: root.fileCount, bytes: root.bytes)
        let todo = paths ?? ScanService.defaultRoots()
        task = Task {
            for path in todo {
                root.child(named: path)?.detach()
                guard let result = await scanInBackground(path, base: progress), !Task.isCancelled else { break }
                result.root.attach(to: root)
                unreadable += result.unreadable
                // A home folder without any blocked folder proves Full Disk Access, whatever the quick check said.
                // (System folders in the temporary area stay blocked even with it.)
                if path == Paths.home && result.unreadable == 0 { hasFullDiskAccess = true }
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

    private func scanInBackground(_ path: String, base: ScanService.Progress) async -> ScanService.Result? {
        // Background QoS runs on the efficiency cores of Apple Silicon.
        let priority: TaskPriority = AppSettings.eco ? .background : .utility
        let inner = Task.detached(priority: priority) {
            ScanService.scan(path) { p in Task { @MainActor in self.progress = base + p } }
        }
        return await withTaskCancellationHandler { await inner.value } onCancel: { inner.cancel() }
    }

    // MARK: Changes

    func refreshVolumes() { volumes = VolumeService.all() }

    func open(_ node: Node) {
        explorerPath = node.chain
        searchText = ""
        pane = .explorer
    }

    /// Deletes all copies of one app and returns how much free space really grew.
    func delete(_ group: CopyGroup) async throws -> Int64 {
        let before = VolumeService.startup()?.free ?? 0
        try await CopyService.delete(group)
        try? await Task.sleep(for: ScanConfig.deleteSettleDelay)
        group.node.detach()
        treeChanged()
        return (startupVolume?.free ?? before) - before
    }

    private func treeChanged() {
        refreshVolumes()
        // The remainder ("System & Other") only makes sense once every area is measured.
        categories = CategoryService.compute(root: root, volume: scanning ? nil : startupVolume)
        revision += 1
    }
}
