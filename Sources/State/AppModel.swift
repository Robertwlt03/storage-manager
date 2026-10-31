import Foundation
import Observation
import SwiftUI
import WidgetKit

/// App state: what is selected, the scanned tree and everything derived from it.
/// The work itself happens in the services; this class only orchestrates them.
@Observable final class AppModel {
    /// An estimate never claims "done" before the scan really is.
    /// APFS reports freed blocks with a short delay.
    private static let waitForFreedSpace: Duration = .seconds(2)
    /// Free space changes without a scan; the menu bar reads the volumes again this often.
    private static let volumeWatchInterval: Duration = .seconds(60)

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
    private(set) var statistics: Statistics?  // size classes of the last finished scan
    /// The used space after each full scan, and what grew between the last two.
    private(set) var history = HistoryStore().points
    private(set) var growth = HistoryStore().growth
    private(set) var totalFreedBytes = Int64(
        UserDefaults.standard.integer(forKey: SettingsKey.totalFreedBytes))
    /// Found once per tree change: each group asks Launch Services and reads an Info.plist.
    private(set) var copyGroups: [CopyGroup] = []
    /// Large files with the same content, found for one tree revision; nil until searched.
    private(set) var duplicateGroups: [[Entry]]?
    private var duplicatesRevision: Int?
    /// Made-up data instead of a scan: nothing is read from the disk and nothing can be removed.
    private(set) var isDemo = false
    /// The temporary area's path as its page shows it; the demo shows a made-up one.
    var shownTemporaryArea: String { isDemo ? DemoData.shownTemporaryArea : Paths.temporaryArea }
    private var scanTask: Task<Void, Never>?
    private var scanID = UUID()  // the current scan; older, canceled runs check it and step aside
    // The newest background refresh of each list; an older one that finishes later steps aside.
    private var appsRefreshID = UUID()
    private var cleanItemsRefreshID = UUID()

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
            scanAutomaticallyIfWanted()
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
        history = demo.history
        growth = demo.growth
        totalFreedBytes = demo.totalFreedBytes
        treeChanged()
    }

    func finishAccessSheet() {
        isShowingAccessSheet = false
        scanAutomaticallyIfWanted()
    }

    private func scanAutomaticallyIfWanted() {
        guard AppSettings.scansAutomatically, lastScan == nil, !isScanning,
            !ProcessInfo.processInfo.isLowPowerModeEnabled
        else { return }
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
            let measuredEveryArea = await measure(areas, scanID: id)
            // A newer scan took over; it finishes the state itself.
            guard scanID == id else { return }
            finishScan(wasCanceled: Task.isCancelled, wasFullScan: reset && measuredEveryArea)
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

    /// False when an area could not be measured and the ones after it were skipped.
    private func measure(_ areas: [String], scanID id: UUID) async -> Bool {
        for (position, area) in areas.enumerated() {
            scanStep = (position + 1, areas.count, area)
            root.child(named: area)?.detach()
            guard let result = await measureInBackground(area, startingFrom: progress, scanID: id),
                !Task.isCancelled, scanID == id
            else { return false }
            add(result, of: area)
        }
        return true
    }

    private func add(_ result: ScanService.Result, of area: String) {
        result.root.attach(to: root)
        unreadableCount += result.unreadableCount
        // A home folder without any blocked folder proves Full Disk Access, whatever the quick
        // check said. (System folders in the temporary area stay blocked even with it.)
        if area == Paths.home && result.unreadableCount == 0 { hasFullDiskAccess = true }
        progress = progressSoFar
        treeChanged()
    }

    private func finishScan(wasCanceled: Bool, wasFullScan: Bool) {
        isScanning = false
        if !wasCanceled { lastScan = Date() }
        treeChanged()  // also reads the volumes again, which the history needs
        if !wasCanceled && wasFullScan {
            UserDefaults.standard.set(root.fileCount, forKey: SettingsKey.lastScanFiles)
            recordHistory()
        }
        refreshApps()
        refreshCleanItems()
    }

    /// Keeps the used space and the folder sizes of this full scan, then compares them with the
    /// scan before.
    private func recordHistory() {
        let now = Date()
        if let usedBytes = startupVolume?.usedBytes {
            history = HistoryService.adding(
                HistoryPoint(date: now, usedBytes: usedBytes), to: history)
        }
        let sizes = HistoryService.folderSizes(
            of: root, at: now, excluded: ScanService.excludedFolders(),
            hadFullAccess: hasFullDiskAccess)
        let store = HistoryStore()
        store.record(history, latest: sizes)
        growth = store.growth
    }

    /// The canceled task still finishes the scan, so the figures match the partial tree.
    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
    }

    private func measureInBackground(
        _ area: String, startingFrom earlierProgress: ScanService.Progress, scanID id: UUID
    ) async -> ScanService.Result? {
        let excluded = ScanService.excludedFolders()
        // Background QoS runs on the efficiency cores of Apple Silicon.
        let measuring = Task.detached(priority: .background) {
            ScanService.scan(area, excluding: excluded) { areaProgress in
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

    /// Spotlight and the apps' bundles are read in the background; the sizes come from the tree.
    func refreshApps() {
        guard !isDemo else { return }
        let refreshID = UUID()
        appsRefreshID = refreshID
        Task {
            let listing = Task.detached(priority: .utility) { AppUsageService.installedApps() }
            var found = await listing.value
            guard appsRefreshID == refreshID else { return }
            for index in found.indices {
                found[index].bytes = root.descendant(at: found[index].path)?.bytes ?? 0
            }
            Motion.animate { apps = found }
        }
    }

    /// What the cleaner could remove; computed once after each scan and shared by the overview and
    /// the cleaner. The folders are listed in the background, the sizes come from the tree.
    /// Compares the large files of equal size once per finished tree; a visit to the page with an
    /// unchanged tree reads nothing again. The demo's files do not exist, so there equal sizes
    /// stand for equal content, without its nameless filler files.
    func findDuplicates() async {
        guard !isScanning, duplicatesRevision != revision else { return }
        let searchedRevision = revision
        duplicateGroups = nil
        let files = SearchService.largeFiles(atLeast: DuplicateService.smallestBytes, in: root)
        let groups =
            isDemo
            ? DuplicateService.sameSizeGroups(
                files.filter { file in file.path?.hasSuffix("/") == false })
            : await DuplicateService.confirmed(DuplicateService.sameSizeGroups(files))
        guard !Task.isCancelled, revision == searchedRevision else { return }
        duplicateGroups = groups
        duplicatesRevision = searchedRevision
    }

    /// What removing all but one file of each duplicate group would free; nil until the
    /// duplicates of the current tree were searched, which only their page starts.
    var duplicateSpareBytes: Int64? {
        guard duplicatesRevision == revision else { return nil }
        return duplicateGroups.map(DuplicateService.spareBytes)
    }

    func refreshCleanItems() {
        // A half-built tree lacks whole areas, which would then be walked on the disk.
        guard hasData, !isDemo, !isScanning else { return }
        let refreshID = UUID()
        cleanItemsRefreshID = refreshID
        Task {
            let excluded = ScanService.excludedFolders()
            let listed =
                await Task.detached(priority: .utility) {
                    CleanerService.removablePaths(excluding: excluded)
                }
                .value
            guard cleanItemsRefreshID == refreshID else { return }
            let withTreeSizes = treeSizes(of: listed)
            let found =
                await Task.detached(priority: .utility) {
                    CleanerService.items(withTreeSizes)
                }
                .value
            guard cleanItemsRefreshID == refreshID else { return }
            Motion.animate { cleanItems = found }
        }
    }

    /// The tree's size of each listed path, read here on the main actor that owns the tree; nil
    /// where the tree folded the entry away.
    private func treeSizes(of listed: [(kind: CleanKind, paths: [String])])
        -> [(kind: CleanKind, paths: [String], treeBytes: [Int64?])]
    {
        listed.map { kind, paths in
            (kind, paths, paths.map { path in root.entryBytes(at: path) })
        }
    }

    func moveToTrash(_ app: AppUsage) throws {
        guard !isDemo else { return }
        try AppUsageService.moveToTrash(app)
        root.descendant(at: app.path)?.detach()
        treeChanged()
        Motion.animate { apps.removeAll { listed in listed.path == app.path } }
    }

    /// Removes the chosen items, measures what really got free, then measures everything again.
    func clean(_ items: [CleanItem]) async -> (freed: Int64, failed: Int) {
        guard !isDemo else { return (0, 0) }
        var failed = 0
        let removedBytes = items.reduce(0) { total, item in total + item.bytes }
        let freed = await freeSpaceGained(removing: removedBytes) {
            failed = await Task.detached(priority: .utility) { CleanerService.clean(items) }.value
        }
        scan()
        return (freed, failed)
    }

    func refreshVolumes() {
        guard !isDemo else { return }
        show(VolumeService.all())
    }

    /// Reads the volumes again every minute until the calling task ends, off the main thread
    /// because a sleeping disk or a network volume can take a moment to answer.
    func watchVolumes() async {
        while !Task.isCancelled {
            if !isDemo {
                show(await Task.detached(priority: .utility) { VolumeService.all() }.value)
            }
            try? await Task.sleep(for: Self.volumeWatchInterval)
        }
    }

    /// Only a real change reaches the views; every assignment would redraw them.
    private func show(_ found: [VolumeInformation]) {
        if found != volumes { volumes = found }
    }

    /// Deletes all copies of one app and returns how much free space really grew.
    func delete(_ group: CopyGroup) async throws -> Int64 {
        guard !isDemo else { return 0 }
        let freed = try await freeSpaceGained(removing: group.node.bytes) {
            try await CopyService.delete(group)
        }
        group.node.detach()
        treeChanged()
        return freed
    }

    /// Runs `removal` and returns what it really freed, which also goes into the total.
    private func freeSpaceGained(
        removing removedBytes: Int64, by removal: () async throws -> Void
    ) async rethrows -> Int64 {
        let freeBefore = VolumeService.startup()?.freeBytes
        try await removal()
        try? await Task.sleep(for: Self.waitForFreedSpace)
        WidgetCenter.shared.reloadAllTimelines()  // the widget shows the new space at once
        let freed = VolumeService.freedBytes(
            before: freeBefore, after: VolumeService.startup()?.freeBytes,
            removedBytes: removedBytes)
        totalFreedBytes += freed
        UserDefaults.standard.set(totalFreedBytes, forKey: SettingsKey.totalFreedBytes)
        return freed
    }

    private func treeChanged() {
        refreshVolumes()
        // The remainder ("System & Other") only makes sense once every area is measured.
        let measuredCategories = CategoryService.compute(
            root: root, volume: isScanning ? nil : startupVolume)
        Motion.animate { categories = measuredCategories }
        // Size classes only from complete data, so they never jump.
        if !isScanning { statistics = StatisticsService.compute(root: root) }
        copyGroups = CopyService.groups(in: root.descendant(at: Paths.temporaryCopies))
        // Drives the tables, which must not update inside an animation (NSTableView reentrancy).
        revision += 1
    }
}
