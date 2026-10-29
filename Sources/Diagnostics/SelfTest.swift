import Foundation

/// `--selftest`: scans real data, compares every area with `du` and prints only counts, sizes and times –
/// never file or folder names.
enum SelfTest {
    static let areas = [Paths.home, Paths.applications, Paths.tempArea]

    static func run() {
        let root = Node.virtualRoot()
        for (i, path) in areas.enumerated() {
            let (start, cpu0) = (Date(), cpuSeconds())
            guard let result = ScanService.scan(path, progress: { _ in }) else {
                fatalError("scan failed")
            }
            let (secs, cpu) = (Date().timeIntervalSince(start), cpuSeconds() - cpu0)
            result.root.attach(to: root)
            let reference = du(path)
            let diff = abs(Double(result.root.bytes - reference)) / Double(max(reference, 1))
            print(
                "Bereich \(i + 1): \(Format.count(result.root.fileCount)) Dateien, \(Format.bytes(result.root.bytes))"
                    + " (du \(Format.bytes(reference)), Abweichung \(String(format: "%.2f", diff * 100)) %),"
                    + " \(result.unreadable) nicht lesbar, \(String(format: "%.1f", secs)) s, CPU \(String(format: "%.1f", cpu)) s"
            )
            precondition(diff < ScanConfig.selfTestTolerance, "scanner and du differ too much")
        }
        let cats = CategoryService.compute(root: root, volume: VolumeService.startup())
        precondition(
            !cats.isEmpty && zip(cats, cats.dropFirst()).allSatisfy { $0.bytes >= $1.bytes })
        print(
            "Kategorien: \(cats.count), zusammen \(Format.bytes(cats.reduce(0) { $0 + $1.bytes }))")

        let searchStart = Date()
        let folders = SearchService.search("a", scope: .folders, in: root)
        let files = SearchService.search("a", scope: .files, in: root)
        let searchMs = Date().timeIntervalSince(searchStart) * 500  // two searches, milliseconds each
        precondition(folders.allSatisfy(\.isFolder) && files.allSatisfy { !$0.isFolder })
        print(
            "Suche: \(folders.count) Ordner, \(files.count) Dateien (Grenze \(ScanConfig.searchLimit)), \(Int(searchMs)) ms je Suche"
        )
        print(
            "Große Dateien ab \(LargeFileThreshold.defaultMB) MB: \(SearchService.largeFiles(atLeast: LargeFileThreshold.bytes(LargeFileThreshold.defaultMB), in: root).count)"
        )
        print(
            "Prüfkopien-Gruppen: \(CopyService.groups(in: root.descendant(at: Paths.tempCopies)).count)"
        )
        print(
            "Datenträger: \(VolumeService.all().count), Vollzugriff: \(PermissionService.hasFullDiskAccess)"
        )
    }

    private static func cpuSeconds() -> Double {
        var u = rusage()
        getrusage(RUSAGE_SELF, &u)
        return Double(u.ru_utime.tv_sec + u.ru_stime.tv_sec) + Double(
            u.ru_utime.tv_usec + u.ru_stime.tv_usec) / 1e6
    }

    private static func du(_ path: String) -> Int64 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        p.arguments = ["-sk", path]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        try? p.run()
        let s = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        return (Int64(s.prefix { $0 != "\t" }) ?? 0) * 1024
    }
}
