import Foundation
import Observation
import SwiftUI

/// App state: what is selected, the scanned tree and everything derived from it.
/// The work itself happens in the services; this class only orchestrates them.
@MainActor @Observable final class AppModel {
    var pane: Pane? = AppSettings.launchPane ?? .overview  // set before the first frame, so nothing animates in
    var explorerPath: [Node] = []
    var searchText = ""
    var searchPresented = false  // the search field has focus; results only replace the page once text is typed
    var searchScope = SearchScope.all
    var showAccessSheet = false
    var columns = NavigationSplitViewVisibility.all  // whether the sidebar is shown
    private var sidebarClosedByUser = false  // the user's choice; only they open it again
    private(set) var windowNarrow = false

    let root = Node.virtualRoot()
    private(set) var revision = 0  // bumped whenever the tree changes; views read it to refresh
    private(set) var scanning = false
    private(set) var progress = ScanService.Progress()
    /// Which area is measured right now (1-based) of how many, and its path.
    private(set) var scanStep = (index: 0, count: 0, path: "")
    private(set) var lastScan: Date?
    private(set) var unreadable = 0
    private(set) var volumes = VolumeService.all()
    private(set) var categories: [Category] = []
    private(set) var hasFullDiskAccess = PermissionService.hasFullDiskAccess
    private(set) var apps: [AppUsage] = []
    private(set) var cleanItems: [CleanItem]?
    private(set) var stats: Statistics?  // key figures of the last finished scan
    private var task: Task<Void, Never>?
    private var scanID = UUID()  // the current scan; older, cancelled runs check it and step aside

    var startupVolume: VolumeInfo? { volumes.first { $0.isRoot } }
    var hasData: Bool { !root.children.isEmpty }
    var isSearching: Bool { !searchQuery.isEmpty }
    var searchQuery: String { searchText.trimmingCharacters(in: .whitespaces) }

    var sidebarVisible: Bool { columns != .detailOnly }
    /// In a narrow window the sidebar floats above the page for a moment instead of taking room beside it.
    private(set) var sidebarOverlay = false
    var sidebarShown: Bool { sidebarVisible || sidebarOverlay }

    /// Animated by SwiftUI, not AppKit (see ARCHITECTURE.md). In a narrow window the sidebar floats above the page.
    func toggleSidebar() {
        if windowNarrow && !sidebarVisible {
            withAnimation(Motion.standard) { sidebarOverlay.toggle() }
            return
        }
        sidebarClosedByUser = sidebarVisible  // closing it now, or opening it again
        withAnimation(Motion.standard) { columns = sidebarVisible ? .detailOnly : .all }
    }

    /// Picking a page, clicking beside the floating sidebar or pressing Escape closes it.
    func closeSidebarOverlay() {
        guard sidebarOverlay else { return }
        withAnimation(Motion.standard) { sidebarOverlay = false }
    }

    private var mainWindow: NSWindow? { NSApp.windows.first { $0.identifier?.rawValue == WindowID.main } }

    /// A narrow window closes the sidebar, a wide one brings it back unless the user closed it, like Mail.
    /// Compares wanted and actual state on every resize, because macOS also closes it on its own (see ARCHITECTURE.md).
    func windowResized() {
        guard let width = mainWindow?.frame.width else { return }
        windowNarrow = width < Layout.sidebarCollapseWidth
        if windowNarrow && sidebarVisible {
            withAnimation(Motion.quick) { columns = .detailOnly }
        } else if !windowNarrow && !sidebarVisible && (!sidebarClosedByUser || sidebarOverlay) {
            sidebarClosedByUser = false
            withAnimation(Motion.quick) {
                sidebarOverlay = false
                columns = .all
            }
        }
    }

    /// Leaves the search: clears the field and closes it (Cancel button, Escape, or picking a page in the sidebar).
    func endSearch() {
        searchText = ""
        searchPresented = false
    }
    var copyGroups: [CopyGroup] {
        _ = revision
        return CopyService.groups(in: root.descendant(at: Paths.tempCopies))
    }

    // MARK: Launch

    /// Asks for Full Disk Access on every launch until it works (one switch instead of many prompts),
    /// then scans if the settings allow it.
    func launch() {
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
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return }  // follows the system's Low Power Mode
        scan()
    }

    // MARK: Scanning

    /// Measures `paths` one after another; with `reset` the tree starts empty.
    func scan(_ paths: [String]? = nil, reset: Bool = true) {
        task?.cancel()
        let id = UUID()
        scanID = id
        if reset {
            root.removeAll()
            unreadable = 0
            explorerPath = []
        }
        // Not animated: the launch scan starts before the first frame (see ARCHITECTURE.md).
        scanning = true
        progress = .init(files: root.fileCount, bytes: root.bytes)
        let todo = paths ?? ScanService.defaultRoots()
        task = Task {
            for (i, path) in todo.enumerated() {
                scanStep = (i + 1, todo.count, path)
                root.child(named: path)?.detach()
                guard let result = await scanInBackground(path, base: progress, id: id), !Task.isCancelled, scanID == id else { break }
                result.root.attach(to: root)
                unreadable += result.unreadable
                // A home folder without any blocked folder proves Full Disk Access, whatever the quick check said.
                // (System folders in the temporary area stay blocked even with it.)
                if path == Paths.home && result.unreadable == 0 { hasFullDiskAccess = true }
                progress = .init(files: root.fileCount, bytes: root.bytes)
                treeChanged()
            }
            guard scanID == id else { return }  // a newer scan took over; it finishes the state itself
            scanning = false
            if !Task.isCancelled {
                lastScan = Date()
                if reset { UserDefaults.standard.set(root.fileCount, forKey: SettingsKey.lastScanFiles) }
            }
            treeChanged()
            refreshApps()
            refreshCleanItems()
        }
    }

    /// How far the scan is, estimated from the file count of the last full scan; the first time from the used space.
    var scanFraction: Double {
        let lastFiles = UserDefaults.standard.integer(forKey: SettingsKey.lastScanFiles)
        let raw = lastFiles > 0
            ? Double(progress.files) / Double(lastFiles)
            : Double(progress.bytes) / Double(max(startupVolume?.used ?? 1, 1))
        return min(raw, ScanConfig.maxEstimatedFraction)
    }

    func cancelScan() {
        task?.cancel()
        scanID = UUID()
        scanning = false
    }

    private func scanInBackground(_ path: String, base: ScanService.Progress, id: UUID) async -> ScanService.Result? {
        // Background QoS runs on the efficiency cores of Apple Silicon.
        let priority = TaskPriority.background
        let inner = Task.detached(priority: priority) {
            ScanService.scan(path) { p in Task { @MainActor in if self.scanID == id { self.progress = base + p } } }
        }
        return await withTaskCancellationHandler { await inner.value } onCancel: { inner.cancel() }
    }

    // MARK: Changes

    func refreshApps() {
        let found = AppUsageService.apps(in: root)
        Motion.animate { apps = found }
    }

    /// Also when the large-file threshold changes, which one of the figures depends on.
    func refreshStats() { stats = StatsService.compute(root: root) }

    /// What the cleaner could remove; computed once after each scan and shared by the overview and the cleaner.
    func refreshCleanItems() {
        guard hasData else { return }
        let found = CleanerService.candidates { [root] path in root.descendant(at: path)?.bytes ?? 0 }
        Motion.animate { cleanItems = found }
    }

    /// Double-click on a row or tile: folders open in the explorer, files show in Finder.
    func activate(_ entry: Entry) {
        if let node = entry.node { open(node) } else if let path = entry.path { FinderService.reveal(path) }
    }

    func moveToTrash(_ app: AppUsage) throws {
        try AppUsageService.moveToTrash(app)
        root.descendant(at: app.path)?.detach()
        treeChanged()
        refreshApps()
    }

    /// Removes the chosen items, measures what really got free, then measures everything again.
    func clean(_ items: [CleanItem]) async -> (freed: Int64, failed: Int) {
        let before = VolumeService.startup()?.free ?? 0
        let failed = await Task.detached(priority: .utility) { CleanerService.clean(items) }.value
        try? await Task.sleep(for: ScanConfig.deleteSettleDelay)
        let freed = (VolumeService.startup()?.free ?? before) - before
        scan()
        return (freed, failed)
    }

    func refreshVolumes() { volumes = VolumeService.all() }

    func open(_ node: Node) {
        explorerPath = node.chain
        endSearch()  // opening a result leaves the search, even when the explorer is already shown
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
        let cats = CategoryService.compute(root: root, volume: scanning ? nil : startupVolume)
        Motion.animate { categories = cats }
        if !scanning { refreshStats() }  // figures only from complete data, so they never jump
        revision += 1  // drives the tables, which must not update inside an animation (NSTableView reentrancy)
    }
}
