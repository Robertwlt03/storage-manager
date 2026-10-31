import Foundation

/// Made-up content for `-demo YES`: every page shows data without reading the disk, for
/// contributors without Full Disk Access, for checking the look and for screenshots. All names are
/// invented; the paths of files and clean-up items do not exist.
struct DemoData {
    let scanRoots: [Node]
    let volume: VolumeInformation
    let apps: [AppUsage]
    let cleanItems: [CleanItem]
    let history: [HistoryPoint]
    let growth: Growth
    let totalFreedBytes = 23_400 * megabyte

    /// What the temporary area's page shows as its place. The demo's folders lie under the real
    /// path, so the app finds them where it looks, but the page shows nothing of this Mac.
    static let shownTemporaryArea = "/private/var/folders/ab/demo0000000000000000000000gn"

    private static let megabyte: Int64 = 1_000_000
    private static let gigabyte: Int64 = 1_000_000_000

    static func make(now: Date = Date()) -> DemoData {
        let scanRoots = [home(), applications(), temporaryArea()]
        return DemoData(
            scanRoots: scanRoots,
            volume: VolumeInformation(
                path: "/", name: "Macintosh HD", format: "APFS", totalBytes: 494 * gigabyte,
                freeBytes: 96 * gigabyte, availableBytes: 118 * gigabyte, isInternal: true,
                isRoot: true),
            apps: apps(now: now, in: scanRoots[1]),
            cleanItems: cleanItems(),
            history: history(now: now),
            growth: growth(now: now))
    }

    // MARK: The history

    /// The used space in gigabytes after each made-up scan, the oldest first, one scan a week.
    private static let usedGigabytesPerScan: [Int64] = [
        372, 374, 373, 377, 379, 381, 380, 384, 389, 391, 393, 398,
    ]
    private static let daysBetweenScans = 7

    private static func history(now: Date) -> [HistoryPoint] {
        let lastIndex = usedGigabytesPerScan.count - 1
        return usedGigabytesPerScan.enumerated()
            .map { index, gigabytes in
                let date =
                    Calendar.current.date(
                        byAdding: .day, value: (index - lastIndex) * daysBetweenScans, to: now)
                    ?? now
                return HistoryPoint(date: date, usedBytes: gigabytes * gigabyte)
            }
    }

    /// The folders that grew since the scan a week before, all in the made-up tree.
    private static func growth(now: Date) -> Growth {
        let weekBefore =
            Calendar.current.date(byAdding: .day, value: -daysBetweenScans, to: now) ?? now
        return Growth(
            since: weekBefore,
            folders: [
                GrownFolder(path: Paths.home + "/Movies", grownBytes: 8_400 * megabyte),
                GrownFolder(path: Paths.home + "/Downloads", grownBytes: 3_200 * megabyte),
                GrownFolder(path: Paths.home + "/Library/Caches", grownBytes: 1_600 * megabyte),
            ])
    }

    // MARK: The tree

    private static func home() -> Node {
        folder(Paths.home, smallFiles: 1_200, smallBytes: 300 * megabyte) { home in
            folder("Downloads", in: home, smallFiles: 800, smallBytes: 2 * gigabyte) { downloads in
                file("Installer.dmg", 3_200 * megabyte, in: downloads)
                file("Photos export.zip", 1_800 * megabyte, in: downloads)
            }
            folder("Documents", in: home, smallFiles: 3_000, smallBytes: 6 * gigabyte) { folder in
                file("Project archive.zip", 2_400 * megabyte, in: folder)
            }
            folder("Pictures", in: home, smallFiles: 200, smallBytes: 400 * megabyte) { pictures in
                folder(
                    "Photos Library.photoslibrary", in: pictures, smallFiles: 20_000,
                    smallBytes: 48 * gigabyte)
            }
            folder("Movies", in: home, smallFiles: 60, smallBytes: 300 * megabyte) { movies in
                file("Holiday 2025.mov", 8_400 * megabyte, in: movies)
                file("Interview.mp4", 2_100 * megabyte, in: movies)
            }
            folder("Music", in: home, smallFiles: 4_000, smallBytes: 12 * gigabyte)
            folder("Library", in: home, smallFiles: 500, smallBytes: 200 * megabyte) { library in
                folder("Caches", in: library, smallFiles: 9_000, smallBytes: 7_500 * megabyte)
                folder(
                    "Application Support", in: library, smallFiles: 7_000,
                    smallBytes: 15 * gigabyte)
                folder("Containers", in: library, smallFiles: 11_000, smallBytes: 22 * gigabyte)
                folder("Developer", in: library, smallFiles: 14_000, smallBytes: 18 * gigabyte)
            }
            folder("Projects", in: home, smallFiles: 12_000, smallBytes: 9 * gigabyte) { projects in
                file("Render.mov", 1_200 * megabyte, in: projects)
            }
        }
    }

    private static func applications() -> Node {
        folder(Paths.applications, smallFiles: 30, smallBytes: 600 * megabyte) { applications in
            for (name, gigabytes) in [
                ("Pixel Studio", 4.1), ("Sound Lab", 2.3), ("Notes Pro", 0.6), ("Old Game", 6.5),
            ] {
                folder(
                    name + ".app", in: applications, smallFiles: 900,
                    smallBytes: Int64(gigabytes * Double(gigabyte)))
            }
        }
    }

    private static func temporaryArea() -> Node {
        folder(Paths.temporaryArea, smallFiles: 0, smallBytes: 0) { area in
            folder(
                TemporaryAreaPart.temporaryFiles.rawValue, in: area, smallFiles: 500,
                smallBytes: 1_100 * megabyte)
            folder(
                TemporaryAreaPart.caches.rawValue, in: area, smallFiles: 1_400,
                smallBytes: 2_200 * megabyte)
            let copiesFolder = TemporaryAreaPart.appCopies.rawValue
            folder(copiesFolder, in: area, smallFiles: 0, smallBytes: 0) { copies in
                folder(
                    "com.example.Browser.code_sign_clone", in: copies, smallFiles: 3_600,
                    smallBytes: 4_200 * megabyte)
            }
            folder(
                TemporaryAreaPart.systemServices.rawValue, in: area, smallFiles: 300,
                smallBytes: 40 * megabyte)
        }
    }

    /// A folder with `smallFiles` files that together hold `smallBytes`; under the virtual root
    /// it becomes a scan root, otherwise it is added to `parent`.
    @discardableResult
    private static func folder(
        _ name: String, in parent: Node? = nil, smallFiles: Int, smallBytes: Int64,
        contents: (Node) -> Void = { _ in }
    ) -> Node {
        let folder = Node(name: name, parent: parent ?? Node.virtualRoot())
        let bytesPerFile = smallFiles > 0 ? smallBytes / Int64(smallFiles) : 0
        for _ in 0..<smallFiles { folder.addFile(bytesPerFile) { "" } }
        contents(folder)
        folder.finish()
        parent?.adopt(folder)
        return folder
    }

    private static func file(_ name: String, _ bytes: Int64, in folder: Node) {
        folder.addFile(bytes) { name }
    }

    /// Three copies of the made-up browser, from the last three days.
    static func copyDetails(now: Date = Date()) -> CopyDetails {
        let today = Calendar.current.startOfDay(for: now)
        return CopyDetails(
            copyCount: 3, versions: [("128.0", 2), ("127.2", 1)],
            days: [2, 1, 0].map { daysAgo in (FileSystem.date(daysBefore: daysAgo, today), 1) })
    }

    // MARK: Apps and clean-up

    private static func apps(now: Date, in applications: Node) -> [AppUsage] {
        [("Pixel Studio", 1), ("Sound Lab", 120), ("Notes Pro", 10), ("Old Game", 400)]
            .map { name, daysAgo in
                let path = applications.name + "/" + name + ".app"
                return AppUsage(
                    path: path, name: name, bundleID: "com.example." + name,
                    lastUsed: FileSystem.date(daysBefore: daysAgo, now),
                    bytes: applications.child(named: name + ".app")?.bytes ?? 0)
            }
    }

    private static func cleanItems() -> [CleanItem] {
        let sizes: [CleanKind: Int64] = [
            .caches: 6_800 * megabyte, .developer: 11 * gigabyte, .logs: 420 * megabyte,
            .temporary: 900 * megabyte, .installers: 2_600 * megabyte, .trash: 1_300 * megabyte,
        ]
        return CleanKind.allCases.map { kind in
            CleanItem(
                kind: kind, paths: [Paths.home + "/.storage-manager-demo/" + kind.rawValue],
                bytes: sizes[kind] ?? 0)
        }
    }
}
