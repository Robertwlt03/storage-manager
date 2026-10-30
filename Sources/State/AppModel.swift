import Foundation
import Observation
import SwiftUI

/// App state: what is selected, the scanned tree and everything derived from it.
/// The work itself happens in the services; this class only orchestrates them.
@Observable final class AppModel {
    /// An estimate never claims "done" before the scan really is.
    private static let largestEstimatedFraction = 0.99
    /// APFS reports freed blocks with a short delay.
    private static let waitForFreedSpace: Duration = .seconds(2)

    /// Set before the first frame, so nothing animates in.
    var pane: Pane? = AppSettings.launchPane ?? .overview
    var explorerPath: [Node] = []
    var searchText = ""
    /// The search field has focus; results only replace the page once text is typed.
    var isSearchPresented = false
    var searchScope = SearchScope.all
    var isShowingAccessSheet = false
    var sidebar = SidebarState()

    let root = Node.virtualRoot()
    private(set) var revision = 0  // bumped whenever the tree changes; views read it to refresh
    private(set) var isScanning = false
    private(set) var progress = ScanService.Progress()
    /// Which area is measured right now (1-based) of how many, and its path.
    private(set) var scanStep = (index: 0, count: 0, path: "")
    private(set) var lastScan: Date?
    private(set) var unreadableCount = 0
    private(set) var volumes = VolumeService.all()
    private(set) var categories: [Category] = []
    private(set) var hasFullDiskAccess = PermissionService.hasFullDiskAccess
    private(set) var apps: [AppUsage] = []
    private(set) var cleanItems: [CleanItem]?
    private(set) var statistics: Statistics?  // key figures of the last finished scan
    /// Found once per tree change: each group asks Launch Services and reads an Info.plist.
    private(set) var copyGroups: [CopyGroup] = []
    /// Made-up data instead of a scan: nothing is read from the disk and nothing can be removed.
    private(set) var isDemo = false
    private var scanTask: Task<Void, Never>?
    private var scanID = UUID()  // the current scan; older, canceled runs check it and step aside

    var startupVolume: VolumeInfo? { volumes.first(where: \.isRoot) }
    /// Reads `revision`, so views that ask this refresh when the tree changes (the tree itself is
    /// not observed).
    var hasData: Bool {
        _ = revision
        return !root.children.isEmpty
    }
    var isSearching: Bool { !searchQuery.isEmpty }
    var searchQuery: String { searchText.trimmingCharacters(in: .whitespaces) }

    /// Animated by SwiftUI, not AppKit (see ARCHITECTURE.md).
    func toggleSidebar() {
        withAnimation(Motion.standard) { sidebar.toggle() }
    }

    func closeSidebarOverlay() {
        guard sidebar.isFloating else { return }
        withAnimation(Motion.standard) { sidebar.closeFloating() }
    }

    private var mainWindow: NSWindow? {
        NSApp.windows.first { window in window.identifier?.rawValue == WindowID.main }
    }

    /// Reads the width from the window, because SwiftUI's width jumps across the limit for a
    /// moment while the window moves (see ARCHITECTURE.md).
    func windowResized() {
        guard let width = mainWindow?.frame.width else { return }
        sidebar.measure(windowWidth: width)
        withAnimation(Motion.quick) { sidebar.fitToWindow() }
    }

    /// Leaves the search: clears the field and closes it (Cancel button, Escape, or picking a page
    /// in the sidebar).
    func endSearch() {
        searchText = ""
        isSearchPresented = false
    }

    // MARK: Launch

    /// Asks for Full Disk Access on every launch until it works (one switch instead of many
    /// prompts), then scans if the settings allow it.
    func launch() {
        if AppSettings.showsDemo {
            showDemo()
            return
        }
        refreshAccess()
        if !hasFullDiskAccess && !AppSettings.shouldSkipAccessSheet {
            isShowingAccessSheet = true
        } else {
            autoScanIfWanted()
        }
    }

    func refreshAccess() {
        guard !isDemo else { return }
        hasFullDiskAccess = PermissionService.hasFullDiskAccess
    }

    private func showDemo() {
        isDemo = true
        let demo = DemoData.make()
        for scanRoot in demo.scanRoots { scanRoot.attach(to: root) }
        volumes = [demo.volume]
        hasFullDiskAccess = true
        lastScan = Date()
        apps = demo.apps
        cleanItems = demo.cleanItems
        treeChanged()
    }

    func finishAccessSheet() {
        isShowingAccessSheet = false
        autoScanIfWanted()
    }

    private func autoScanIfWanted() {
        guard AppSettings.autoScan, lastScan == nil, !isScanning else { return }
        // Follows the system's Low Power Mode.
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return }
        scan()
    }

    // MARK: Scanning

    /// Measures `paths` one after another; with `reset` the tree starts empty.
    func scan(_ paths: [String]? = nil, reset: Bool = true) {
        guard !isDemo else { return }
        let id = startNewScan()
        if reset { forgetPreviousScan() }
        // Not animated: the launch scan starts before the first frame (see ARCHITECTURE.md).
        isScanning = true
        progress = progressSoFar
        let areas = paths ?? ScanService.defaultRoots()
        scanTask = Task {
            await measure(areas, scanID: id)
            // A newer scan took over; it finishes the state itself.
            guard scanID == id else { return }
            finishScan(wasCanceled: Task.isCancelled, wasFullScan: reset)
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
        copyGroups = []
        unreadableCount = 0
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
        unreadableCount += result.unreadable
        // A home folder without any blocked folder proves Full Disk Access, whatever the quick
        // check said. (System folders in the temporary area stay blocked even with it.)
        if area == Paths.home && result.unreadable == 0 { hasFullDiskAccess = true }
        progress = progressSoFar
        treeChanged()
    }

    private func finishScan(wasCanceled: Bool, wasFullScan: Bool) {
        isScanning = false
        if !wasCanceled {
            lastScan = Date()
            if wasFullScan {
                UserDefaults.standard.set(root.fileCount, forKey: SettingsKey.lastScanFiles)
            }
        }
        treeChanged()
        refreshApps()
        refreshCleanItems()
    }

    /// How far the scan is, estimated from the file count of the last full scan; the first time
    /// from the used space.
    var scanFraction: Double {
        let filesOfLastFullScan = UserDefaults.standard.integer(forKey: SettingsKey.lastScanFiles)
        let estimate =
            filesOfLastFullScan > 0
            ? Double(progress.files) / Double(filesOfLastFullScan)
            : Double(progress.bytes) / Double(max(startupVolume?.usedBytes ?? 1, 1))
        return min(estimate, Self.largestEstimatedFraction)
    }

    func cancelScan() {
        scanTask?.cancel()
        scanID = UUID()
        isScanning = false
    }

    private func measureInBackground(
        _ area: String, startingFrom earlierProgress: ScanService.Progress, scanID id: UUID
    ) async -> ScanService.Result? {
        // Background QoS runs on the efficiency cores of Apple Silicon.
        let measuring = Task.detached(priority: .background) {
            ScanService.scan(area) { areaProgress in
                Task { @MainActor in self.showProgress(earlierProgress + areaProgress, ofScan: id) }
            }
        }
        return await withTaskCancellationHandler {
            await measuring.value
        } onCancel: {
            measuring.cancel()
        }
    }

    /// Shows a scan's progress, unless a newer scan started meanwhile.
    private func showProgress(_ newProgress: ScanService.Progress, ofScan id: UUID) {
        if scanID == id { progress = newProgress }
    }
}

extension AppModel {
    // MARK: Changes

    /// The versions and sizes of an app's copies, read in the background. The demo's copies exist
    /// only in the made-up tree, so their details are made up too.
    func copyDetails(of group: CopyGroup) async -> CopyDetails {
        if isDemo { return DemoData.copyDetails() }
        return await Task.detached(priority: .utility) { CopyService.details(group) }.value
    }

    func refreshApps() {
        guard !isDemo else { return }
        let found = AppUsageService.apps(in: root)
        Motion.animate { apps = found }
    }

    /// Also when the large-file threshold changes, which one of the figures depends on.
    func refreshStatistics() {
        let largeFileBytes = LargeFileThreshold.bytes(AppSettings.largeFileMegabytes)
        statistics = StatisticsService.compute(root: root, largeFileBytes: largeFileBytes)
    }

    /// What the cleaner could remove; computed once after each scan and shared by the overview and
    /// the cleaner.
    func refreshCleanItems() {
        guard hasData, !isDemo else { return }
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
        guard !isDemo else { return }
        try AppUsageService.moveToTrash(app)
        root.descendant(at: app.path)?.detach()
        treeChanged()
        refreshApps()
    }

    /// Removes the chosen items, measures what really got free, then measures everything again.
    func clean(_ items: [CleanItem]) async -> (freed: Int64, failed: Int) {
        guard !isDemo else { return (0, 0) }
        var failed = 0
        let freed = await freeSpaceGained {
            failed = await Task.detached(priority: .utility) { CleanerService.clean(items) }.value
        }
        scan()
        return (freed, failed)
    }

    func refreshVolumes() {
        guard !isDemo else { return }
        volumes = VolumeService.all()
    }

    func open(_ node: Node) {
        explorerPath = node.nodesFromRoot
        endSearch()  // opening a result leaves the search, even when the explorer is already shown
        pane = .explorer
    }

    /// Deletes all copies of one app and returns how much free space really grew.
    func delete(_ group: CopyGroup) async throws -> Int64 {
        guard !isDemo else { return 0 }
        let freed = try await freeSpaceGained { try await CopyService.delete(group) }
        group.node.detach()
        treeChanged()
        return freed
    }

    /// Runs the removal, waits until APFS reports the freed blocks and returns how much free space
    /// really grew.
    private func freeSpaceGained(by removal: () async throws -> Void) async rethrows -> Int64 {
        let freeBefore = VolumeService.startup()?.freeBytes ?? 0
        try await removal()
        try? await Task.sleep(for: Self.waitForFreedSpace)
        return (VolumeService.startup()?.freeBytes ?? freeBefore) - freeBefore
    }

    private func treeChanged() {
        refreshVolumes()
        // The remainder ("System & Other") only makes sense once every area is measured.
        let measuredCategories = CategoryService.compute(
            root: root, volume: isScanning ? nil : startupVolume)
        Motion.animate { categories = measuredCategories }
        // Figures only from complete data, so they never jump.
        if !isScanning { refreshStatistics() }
        copyGroups = CopyService.groups(in: root.descendant(at: Paths.temporaryCopies))
        // Drives the tables, which must not update inside an animation (NSTableView reentrancy).
        revision += 1
    }
}
