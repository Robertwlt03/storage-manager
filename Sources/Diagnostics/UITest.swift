import AppKit
import SwiftUI

/// `open … --args -uiTest <folder>`: drives the running app like a very fast user and tries to
/// break it. It switches pages and views during scans, cancels and restarts scans, flips settings,
/// digs into folders and searches, checks the data after every step and saves a picture of the
/// window. It never deletes, cleans up or moves anything to the Trash, prints only counts (no
/// names) and restores the user's settings at the end.
@MainActor enum UITest {
    private static let changedSettingKeys = [
        SettingsKey.layoutMode, SettingsKey.largeFileMegabytes, SettingsKey.unusedDays,
    ]
    private static let roundsDuringScan = 3
    /// While the first scan runs, every fifth step also types a search.
    private static let searchEveryNthStep = 5
    private static let sampleQuery = "a"
    private static let searchQueries = ["a", "lib", "zzzzqq", " ", "e", ""]
    private static let folderDepth = 5
    private static let cleanerRefreshes = 3
    private static let scanTimeout: TimeInterval = 240
    private static let scanPollInterval: Duration = .milliseconds(500)
    private static let validFractions = 0.0...1.0
    /// The main window; smaller windows such as the settings are not photographed.
    private static let minimumPictureWidth = 600.0
    private static let millisecondsPerSecond = 1000.0
    private static let secondFractionDigits = 3
    private static let timeFormat = Date.FormatStyle.dateTime.hour().minute().second()
        .secondFraction(.fractional(secondFractionDigits))

    /// How long each step waits for the app to settle, in seconds.
    private enum Pause {
        static let betweenSwitches = 0.25
        static let afterCancel = 0.3
        static let afterSecondCancel = 0.2
        static let afterDoubleStart = 1.0
        static let afterRestart = 0.5
        static let afterScan = 1.0
        static let perPage = 0.8
        static let perFolder = 0.15
        static let perSearch = 0.4
        static let perSetting = 0.3
        static let afterCleanerRefresh = 0.5
        static let perPageDuringRescan = 0.3
        static let atTheEnd = 1.0
    }

    private static var problems: [String] = []
    private static var stepCount = 0
    private static var pictureFolder = URL(fileURLWithPath: NSTemporaryDirectory())

    static func run(_ model: AppModel, into pictureFolderPath: String) async {
        preparePictureFolder(at: pictureFolderPath)
        let savedSettings = saveSettings()
        defer { restore(savedSettings) }
        log("Start, Full Disk Access: \(model.hasFullDiskAccess)")

        await switchAroundDuringScan(model)
        await checkScanControls(model)
        await waitForScan(model)
        await visitEveryPage(model)
        await browseFolders(model)
        await searchEveryScope(model)
        await flipSettings(model)
        await rescanOnOverview(model)

        reportResult()
    }

    // MARK: Scenarios

    /// Jump between pages, layouts and searches while the first scan is still running.
    private static func switchAroundDuringScan(_ model: AppModel) async {
        if !model.isScanning { model.scan() }
        for round in 0..<roundsDuringScan {
            for pane in allPanes(model) {
                model.pane = pane
                changeSetting(
                    SettingsKey.layoutMode, to: (round + stepCount) % LayoutMode.allCases.count)
                model.searchText = stepCount % searchEveryNthStep == 0 ? sampleQuery : ""
                await step(
                    "Chaos \(round) \(logName(of: pane))", model, wait: Pause.betweenSwitches,
                    picture: false)
            }
        }
        model.searchText = ""
    }

    /// Cancel and restart scans in quick succession, also twice in a row.
    private static func checkScanControls(_ model: AppModel) async {
        model.cancelScan()
        await step("Cancel", model, wait: Pause.afterCancel)
        model.cancelScan()
        await step("Double cancel", model, wait: Pause.afterSecondCancel)
        model.scan()
        model.scan()
        await step("Double start", model, wait: Pause.afterDoubleStart)
        model.cancelScan()
        model.scan()
        await step("Cancel and restart at once", model, wait: Pause.afterRestart)
        check(model.isScanning, "Scan not running after restart")
    }

    private static func waitForScan(_ model: AppModel) async {
        let start = Date()
        while model.isScanning && Date().timeIntervalSince(start) < scanTimeout {
            try? await Task.sleep(for: scanPollInterval)
        }
        check(!model.isScanning, "Scan not finished after \(Int(scanTimeout)) s")
        log(
            "Scan finished after \(Int(Date().timeIntervalSince(start))) s:"
                + " \(model.root.fileCount) files, \(model.categories.count) categories"
        )
        await step("After the scan", model, wait: Pause.afterScan)
    }

    /// Every page in light and dark, as list and as grid, with a picture of each.
    private static func visitEveryPage(_ model: AppModel) async {
        for appearance in [NSAppearance(named: .aqua), NSAppearance(named: .darkAqua)] {
            // Only for this test run; the app itself follows the system.
            NSApp.appearance = appearance
            for pane in allPanes(model) {
                for layout in LayoutMode.allCases where layout == .list || pane.supportsGrid {
                    changeSetting(SettingsKey.layoutMode, to: layout.rawValue)
                    model.pane = pane
                    let appearanceName = appearance?.name.rawValue ?? ""
                    await step(
                        "Page \(logName(of: pane)) \(appearanceName) \(layout)", model,
                        wait: Pause.perPage)
                }
            }
        }
        changeSetting(SettingsKey.layoutMode, to: LayoutMode.list.rawValue)
        NSApp.appearance = nil
    }

    /// Open every category, go five levels deep, back out, and repeat quickly.
    private static func browseFolders(_ model: AppModel) async {
        for category in model.categories {
            guard let node = category.node else { continue }
            model.open(node)
            var current = node
            for _ in 0..<folderDepth {
                guard let next = current.children.first else { break }
                model.explorerPath.append(next)
                current = next
                await step("Folder deeper", model, wait: Pause.perFolder, picture: false)
            }
            while !model.explorerPath.isEmpty { model.explorerPath.removeLast() }
            await step("Folder back", model, wait: Pause.perFolder, picture: false)
        }
    }

    private static func searchEveryScope(_ model: AppModel) async {
        for query in searchQueries {
            for scope in SearchScope.allCases {
                model.searchScope = scope
                model.searchText = query
                await step("Search", model, wait: Pause.perSearch, picture: false)
                let hits = SearchService.search(query, scope: scope, in: model.root)
                check(hits.count <= ScanLimits.searchLimit, "Search returns more than the limit")
                check(
                    scope != .folders || hits.allSatisfy(\.isFolder),
                    "Folder search returns files")
            }
        }
        model.searchText = ""
    }

    /// Thresholds and day ranges, each on the page that shows it.
    private static func flipSettings(_ model: AppModel) async {
        model.pane = .largeFiles
        for megabytes in LargeFileThreshold.megabyteOptions {
            changeSetting(SettingsKey.largeFileMegabytes, to: megabytes)
            await step("Large files \(megabytes)", model, wait: Pause.perSetting, picture: false)
        }
        model.pane = .apps
        for days in CleanUpRules.unusedDayOptions {
            changeSetting(SettingsKey.unusedDays, to: days)
            await step("Days \(days)", model, wait: Pause.perSetting, picture: false)
        }
        model.pane = .cleaner
        for _ in 0..<cleanerRefreshes { model.refreshCleanItems() }
        await step("Cleaner refresh", model, wait: Pause.afterCleanerRefresh)
    }

    /// The scenario that crashed Swift Charts: rescan while the page with the chart is open, then
    /// switch around.
    private static func rescanOnOverview(_ model: AppModel) async {
        model.pane = .overview
        model.scan()
        for pane in allPanes(model) + [.overview, .explorer, .overview] {
            model.pane = pane
            await step(
                "Rescan \(logName(of: pane))", model, wait: Pause.perPageDuringRescan,
                picture: false)
        }
        await waitForScan(model)
        model.pane = .overview
        await step("Overview at the end", model, wait: Pause.atTheEnd)
    }

    // MARK: Steps and checks

    private static func step(
        _ name: String, _ model: AppModel, wait seconds: Double, picture: Bool = true
    ) async {
        stepCount += 1
        try? await Task.sleep(for: .milliseconds(Int(seconds * millisecondsPerSecond)))
        checkData(model, name)
        if picture { savePicture(named: String(format: "%03d", stepCount)) }
        log("\(stepCount) \(name) ok")
    }

    /// Consistency of what every page shows.
    private static func checkData(_ model: AppModel, _ name: String) {
        let categories = model.categories
        check(
            zip(categories, categories.dropFirst())
                .allSatisfy { larger, smaller in larger.bytes >= smaller.bytes },
            "\(name): categories not sorted")
        check(categories.allSatisfy { category in category.bytes >= 0 }, "\(name): negative size")
        check(validFractions.contains(model.scanFraction), "\(name): progress outside 0–100 %")
        check(model.root.bytes >= 0 && model.root.fileCount >= 0, "\(name): tree invalid")
        if !model.explorerPath.isEmpty {
            check(
                zip(model.explorerPath, model.explorerPath.dropFirst())
                    .allSatisfy { parent, child in child.path.hasPrefix(parent.path) },
                "\(name): folder path does not fit together")
        }
    }

    private static func check(_ isFine: Bool, _ problem: String) {
        if !isFine { problems.append(problem) }
    }

    private static func reportResult() {
        log(
            problems.isEmpty
                ? "RESULT: no problems in \(stepCount) steps"
                : "RESULT: \(problems.count) problems")
        for problem in problems { log("PROBLEM: \(problem)") }
    }

    // MARK: Helpers

    private static func allPanes(_ model: AppModel) -> [Pane] {
        let otherVolumes = model.volumes.filter { volume in !volume.isRoot }
        return Pane.main + Pane.tidy + Pane.system
            + otherVolumes.map { volume in .volume(volume.path) }
    }

    /// A volume's launch key is its mount point, so the log only says "volume" to keep names out of
    /// it.
    private static func logName(of pane: Pane) -> String {
        if case .volume = pane { return "volume" }
        return pane.launchKey
    }

    private static func changeSetting(_ key: String, to value: Any) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private static func saveSettings() -> [(String, Any?)] {
        let storedSettings = UserDefaults.standard.persistentDomain(
            forName: Bundle.main.bundleIdentifier ?? "")
        return changedSettingKeys.map { key in (key, storedSettings?[key]) }
    }

    private static func restore(_ savedSettings: [(String, Any?)]) {
        for (key, value) in savedSettings {
            if let value {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    private static func preparePictureFolder(at path: String) {
        pictureFolder = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(
            at: pictureFolder, withIntermediateDirectories: true)
    }

    private static func savePicture(named name: String) {
        guard let view = pictureWindow?.contentView,
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?
            .write(to: pictureFolder.appendingPathComponent(name + ".png"))
    }

    private static var pictureWindow: NSWindow? {
        NSApp.windows.first { window in
            window.isVisible && window.frame.width > minimumPictureWidth
        }
    }

    private static func log(_ text: String) {
        let time = Date().formatted(timeFormat)
        print("[UITest] \(time) \(text)")
        fflush(stdout)
    }
}
