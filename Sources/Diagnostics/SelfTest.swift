import Foundation

/// `--selftest`: scans real data, compares every area with `du` and prints only counts, sizes and times –
/// never file or folder names.
enum SelfTest {
    private static let areas = [Paths.home, Paths.applications, Paths.tempArea]
    /// How far the scanner may differ from `du`, as a fraction.
    private static let tolerance = 0.02
    private static let sampleQuery = "a"
    private static let percent = 100.0
    private static let millisecondsPerSecond = 1000.0
    private static let microsecondsPerSecond = 1e6
    /// `du -k` counts in blocks of this many bytes.
    private static let bytesPerKilobyte: Int64 = 1024

    static func run() {
        let root = Node.virtualRoot()
        measureEveryArea(into: root)
        checkCategories(of: root)
        checkSearch(in: root)
        reportLargeFiles(in: root)
        reportCopies(in: root)
        reportVolumes()
    }

    private static func measureEveryArea(into root: Node) {
        for (index, path) in areas.enumerated() {
            let (startTime, cpuAtStart) = (Date(), cpuSeconds())
            guard let result = ScanService.scan(path, progress: { _ in }) else {
                fatalError("scan failed")
            }
            let seconds = Date().timeIntervalSince(startTime)
            let cpuTime = cpuSeconds() - cpuAtStart
            result.root.attach(to: root)
            let reference = measureWithDiskUsage(path)
            let deviation =
                abs(Double(result.root.bytes - reference)) / Double(max(reference, 1))
            let deviationText = String(format: "%.2f", deviation * percent)
            let secondsText = String(format: "%.1f", seconds)
            let cpuText = String(format: "%.1f", cpuTime)
            print(
                "Area \(index + 1): \(Format.count(result.root.fileCount)) files,"
                    + " \(Format.bytes(result.root.bytes)) (du \(Format.bytes(reference)),"
                    + " deviation \(deviationText) %), \(result.unreadable) unreadable,"
                    + " \(secondsText) s, CPU \(cpuText) s"
            )
            precondition(deviation < tolerance, "scanner and du differ too much")
        }
    }

    private static func checkCategories(of root: Node) {
        let categories = CategoryService.compute(root: root, volume: VolumeService.startup())
        let isSortedBySize = zip(categories, categories.dropFirst())
            .allSatisfy { larger, smaller in larger.bytes >= smaller.bytes }
        precondition(!categories.isEmpty && isSortedBySize)
        let totalBytes = categories.reduce(0) { total, category in total + category.bytes }
        print("Categories: \(categories.count), total \(Format.bytes(totalBytes))")
    }

    private static func checkSearch(in root: Node) {
        let searchStart = Date()
        let folders = SearchService.search(sampleQuery, scope: .folders, in: root)
        let files = SearchService.search(sampleQuery, scope: .files, in: root)
        let searchCount = 2.0
        let millisecondsPerSearch =
            Date().timeIntervalSince(searchStart) * millisecondsPerSecond / searchCount
        precondition(folders.allSatisfy(\.isFolder) && files.allSatisfy { file in !file.isFolder })
        print(
            "Search: \(folders.count) folders, \(files.count) files"
                + " (limit \(ScanConfig.searchLimit)), \(Int(millisecondsPerSearch)) ms per search"
        )
    }

    private static func reportLargeFiles(in root: Node) {
        let threshold = LargeFileThreshold.bytes(LargeFileThreshold.defaultMB)
        let largeFiles = SearchService.largeFiles(atLeast: threshold, in: root)
        print("Large files from \(LargeFileThreshold.defaultMB) MB: \(largeFiles.count)")
    }

    private static func reportCopies(in root: Node) {
        let groups = CopyService.groups(in: root.descendant(at: Paths.tempCopies))
        print("Signature copy groups: \(groups.count)")
    }

    private static func reportVolumes() {
        print(
            "Volumes: \(VolumeService.all().count),"
                + " Full Disk Access: \(PermissionService.hasFullDiskAccess)")
    }

    private static func cpuSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        let wholeSeconds = usage.ru_utime.tv_sec + usage.ru_stime.tv_sec
        let microseconds = usage.ru_utime.tv_usec + usage.ru_stime.tv_usec
        return Double(wholeSeconds) + Double(microseconds) / microsecondsPerSecond
    }

    /// The size `du` reports for a folder, as a reference for the scanner.
    private static func measureWithDiskUsage(_ path: String) -> Int64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try? process.run()
        let text = String(
            decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        let kilobytes = Int64(text.prefix { character in character != "\t" }) ?? 0
        return kilobytes * bytesPerKilobyte
    }
}
