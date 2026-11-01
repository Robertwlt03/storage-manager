import Foundation

/// What the model knows without changing anything: figures, the summary and the report, read
/// from the state in AppModel.swift.
extension AppModel {
    private static let largestEstimatedFraction = 0.99

    var startupVolume: VolumeInformation? { volumes.first(where: \.isRoot) }
    /// Reads `revision`, because the tree itself is not observed.
    var hasData: Bool {
        _ = revision
        return !root.children.isEmpty
    }
    var isSearching: Bool { !searchQuery.isEmpty }
    var searchQuery: String { searchText.trimmingCharacters(in: .whitespaces) }

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

    /// The versions and sizes of an app's copies, read in the background. The demo's copies exist
    /// only in the made-up tree, so their details are made up too.
    func copyDetails(of group: CopyGroup) async -> CopyDetails {
        if isDemo { return DemoData.copyDetails() }
        return await Task.detached(priority: .utility) { CopyService.details(group) }.value
    }

    /// What the clean-up suggestions would free; nil until they are listed.
    var cleanableBytes: Int64? { cleanItems?.reduce(0) { total, item in total + item.bytes } }

    /// The storage in a few sentences, from the last scan and the clean-up suggestions.
    func summary(unusedDays: Int) -> String {
        let copyBytes = copyGroups.reduce(0) { total, group in total + group.node.bytes }
        let unusedApps = AppUsageService.unused(apps, days: unusedDays)
        let facts = SummaryService.Input(
            volume: startupVolume, categories: isScanning ? [] : categories,
            cleanableBytes: cleanableBytes, copyBytes: copyBytes, unusedAppCount: unusedApps.count,
            freedBytes: totalFreedBytes)
        return SummaryService.text(facts)
    }

    /// The last scan as a report, with the large files from the threshold chosen on their page.
    func report() -> String {
        let minimumBytes = LargeFileThreshold.bytes(AppSettings.largeFileMegabytes)
        return ReportService.text(
            .init(
                date: lastScan ?? Date(), summary: summary(unusedDays: AppSettings.unusedDays),
                categories: categories,
                largeFiles: SearchService.largeFiles(atLeast: minimumBytes, in: root)))
    }
}
