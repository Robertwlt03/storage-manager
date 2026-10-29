import Foundation
import Observation
import SwiftUI

/// App state: what is selected, the scanned tree and everything derived from it.
/// The work itself happens in the services; this class only orchestrates them.
@MainActor @Observable final class AppModel {
    /// An estimate never claims "done" before the scan really is.
    private static let largestEstimatedFraction = 0.99
    /// APFS reports freed blocks with a short delay.
    private static let waitForFreedSpace: Duration = .seconds(2)

    /// Set before the first frame, so nothing animates in.
    var pane: Pane? = AppSettings.launchPane ?? .overview
    var explorerPath: [Node] = []
    var searchText = ""
    /// The search field has focus; results only replace the page once text is typed.
    var searchPresented = false
    var searchScope = SearchScope.all
    var showAccessSheet = false
    var columns = NavigationSplitViewVisibility.all  // whether the sidebar is shown
    private var wasSidebarClosedByUser = false  // the user's choice; only they open it again
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
    private var scanTask: Task<Void, Never>?
    private var scanID = UUID()  // the current scan; older, cancelled runs check it and step aside

    var startupVolume: VolumeInfo? { volumes.first { volume in volume.isRoot } }
    var hasData: Bool { !root.children.isEmpty }
    var isSearching: Bool { !searchQuery.isEmpty }
    var searchQuery: String { searchText.trimmingCharacters(in: .whitespaces) }

    private var isSidebarVisible: Bool { columns != .detailOnly }
    /// In a narrow window the sidebar floats above the page for a moment instead of taking room beside it.
    private(set) var sidebarOverlay = false
    var sidebarShown: Bool { isSidebarVisible || sidebarOverlay }

    /// Animated by SwiftUI, not AppKit (see ARCHITECTURE.md). In a narrow window the sidebar floats above the page.
    func toggleSidebar() {
        if windowNarrow && !isSidebarVisible {
            withAnimation(Motion.standard) { sidebarOverlay.toggle() }
            return
        }
        wasSidebarClosedByUser = isSidebarVisible  // closing it now, or opening it again
        withAnimation(Motion.standard) { columns = isSidebarVisible ? .detailOnly : .all }
    }

    /// Picking a page, clicking beside the floating sidebar or pressing Escape closes it.
    func closeSidebarOverlay() {
        guard sidebarOverlay else { return }
        withAnimation(Motion.standard) { sidebarOverlay = false }
    }

    private var mainWindow: NSWindow? {
        NSApp.windows.first { window in window.identifier?.rawValue == WindowID.main }
    }

    /// A narrow window closes the sidebar, a wide one brings it back unless the user closed it, like Mail.
    /// Compares wanted and actual state on every resize, because macOS also closes it on its own (see ARCHITECTURE.md).
    func windowResized() {
        guard let width = mainWindow?.frame.width else { return }
        windowNarrow = width < Layout.sidebarCollapseWidth
        if windowNarrow && isSidebarVisible {
            withAnimation(Motion.quick) { columns = .detailOnly }
        } else if shouldBringSidebarBack {
            wasSidebarClosedByUser = false
            withAnimation(Motion.quick) {
                sidebarOverlay = false
                columns = .all
            }
        }
    }

    private var shouldBringSidebarBack: Bool {
        !windowNarrow && !isSidebarVisible && (!wasSidebarClosedByUser || sidebarOverlay)
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
        if !hasFullDiskAccess && !AppSettings.shouldSkipAccessSheet {
            showAccessSheet = true
        } else {
            autoScanIfWanted()
        }
    }

    func refreshAccess() { hasFullDiskAccess = PermissionService.hasFullDiskAccess }

    func finishAccessSheet() {
        showAccessSheet = false
        autoScanIfWanted()
    }

    private func autoScanIfWanted() {
        guard AppSettings.autoScan, lastScan == nil, !scanning else { return }
        // Follows the system's Low Power Mode.
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return }
        scan()
    }

    // MARK: Scanning

    /// Measures `paths` one after another; with `reset` the tree starts empty.
    func scan(_ paths: [String]? = nil, reset: Bool = true) {
        let id = startNewScan()
        if reset { forgetPreviousScan() }
        // Not animated: the launch scan starts before the first frame (see ARCHITECTURE.md).
        scanning = true
        progress = progressSoFar
        let areas = paths ?? ScanService.defaultRoots()
        scanTask = Task {
            await measure(areas, scanID: id)
            // A newer scan took over; it finishes the state itself.
            guard scanID == id else { return }
            finishScan(wasCancelled: Task.isCancelled, wasFullScan: reset)
        }
    }

    /// Cancels the running scan and returns the ID of the new one.
    private func startNewScan() -> UUID {
        scanTask?.cancel()
        let id = UUID()
        scanID = id
        return id
    }

    private func forgetPreviousScan() {
        root.removeAll()
        unreadable = 0
        explorerPath = []
    }

    private var progressSoFar: ScanService.Progress {
        .init(files: root.fileCount, bytes: root.bytes)
    }

    private func measure(_ areas: [String], scanID id: UUID) async {
        for (position, area) in areas.enumerated() {
            scanStep = (position + 1, areas.count, area)
            root.child(named: area)?.detach()
            guard let result = await measureInBackground(area, startingFrom: progress, scanID: id),
                !Task.isCancelled, scanID == id
            else { return }
            add(result, of: area)
        }
    }

    private func add(_ result: ScanService.Result, of area: String) {
        result.root.attach(to: root)
        unreadable += result.unreadable
        // A home folder without any blocked folder proves Full Disk Access, whatever the quick check said.
        // (System folders in the temporary area stay blocked even with it.)
        if area == Paths.home && result.unreadable == 0 { hasFullDiskAccess = true }
        progress = progressSoFar
        treeChanged()
    }

    private func finishScan(wasCancelled: Bool, wasFullScan: Bool) {
        scanning = false
        if !wasCancelled {
            lastScan = Date()
            if wasFullScan {
                UserDefaults.standard.set(root.fileCount, forKey: SettingsKey.lastScanFiles)
            }
        }
        treeChanged()
        refreshApps()
        refreshCleanItems()
    }

    /// How far the scan is, estimated from the file count of the last full scan; the first time from the used space.
    var scanFraction: Double {
        let filesOfLastFullScan = UserDefaults.standard.integer(forKey: SettingsKey.lastScanFiles)
        let estimate =
            filesOfLastFullScan > 0
            ? Double(progress.files) / Double(filesOfLastFullScan)
            : Double(progress.bytes) / Double(max(startupVolume?.used ?? 1, 1))
        return min(estimate, Self.largestEstimatedFraction)
    }

    func cancelScan() {
        scanTask?.cancel()
        scanID = UUID()
        scanning = false
    }

    private func measureInBackground(
        _ area: String, startingFrom earlierProgress: ScanService.Progress, scanID id: UUID
    ) async -> ScanService.Result? {
        // Background QoS runs on the efficiency cores of Apple Silicon.
        let measuring = Task.detached(priority: .background) {
            ScanService.scan(area) { areaProgress in
                Task { @MainActor in
                    if self.scanID == id { self.progress = earlierProgress + areaProgress }
                }
            }
        }
        return await withTaskCancellationHandler {
            await measuring.value
        } onCancel: {
            measuring.cancel()
        }
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
        let found = CleanerService.candidates { [root] path in
            root.descendant(at: path)?.bytes ?? 0
        }
        Motion.animate { cleanItems = found }
    }

    /// Double-click on a row or tile: folders open in the explorer, files show in Finder.
    func activate(_ entry: Entry) {
        if let node = entry.node {
            open(node)
        } else if let path = entry.path {
            FinderService.reveal(path)
        }
    }

    func moveToTrash(_ app: AppUsage) throws {
        try AppUsageService.moveToTrash(app)
        root.descendant(at: app.path)?.detach()
        treeChanged()
        refreshApps()
    }

    /// Removes the chosen items, measures what really got free, then measures everything again.
    func clean(_ items: [CleanItem]) async -> (freed: Int64, failed: Int) {
        let freeBefore = VolumeService.startup()?.free ?? 0
        let failed = await Task.detached(priority: .utility) { CleanerService.clean(items) }.value
        try? await Task.sleep(for: Self.waitForFreedSpace)
        let freed = (VolumeService.startup()?.free ?? freeBefore) - freeBefore
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
        let freeBefore = VolumeService.startup()?.free ?? 0
        try await CopyService.delete(group)
        try? await Task.sleep(for: Self.waitForFreedSpace)
        group.node.detach()
        treeChanged()
        return (startupVolume?.free ?? freeBefore) - freeBefore
    }

    private func treeChanged() {
        refreshVolumes()
        // The remainder ("System & Other") only makes sense once every area is measured.
        let measuredCategories = CategoryService.compute(
            root: root, volume: scanning ? nil : startupVolume)
        Motion.animate { categories = measuredCategories }
        // Figures only from complete data, so they never jump.
        if !scanning { refreshStats() }
        // Drives the tables, which must not update inside an animation (NSTableView reentrancy).
        revision += 1
    }
}
