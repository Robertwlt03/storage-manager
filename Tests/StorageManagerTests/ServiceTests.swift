import Foundation
import Testing

@testable import StorageManager

/// The decisions the services make from a scanned tree, checked on hand-built trees.
@Suite("Services")
struct ServiceTests {
    private static let gigabyte: Int64 = 1_000_000_000

    private static func homeTree() -> Node { TestTree.home() }

    private static func bytes(of kind: CategoryKind, in categories: [StorageManager.Category])
        -> Int64
    {
        categories.first { category in category.kind == kind }?.bytes ?? 0
    }

    @Test("The most specific folder decides the category, unnamed folders inherit theirs")
    func categories() {
        let categories = CategoryService.compute(root: Self.homeTree(), volume: nil)
        #expect(Self.bytes(of: .downloads, in: categories) == TestTree.big)
        #expect(Self.bytes(of: .caches, in: categories) == TestTree.big)
        // Home's own file, Library's own file and Projects all count as the home folder's kind.
        #expect(Self.bytes(of: .user, in: categories) == TestTree.big * 3)
    }

    @Test("Categories come biggest first, and empty ones are left out")
    func categoryOrder() {
        let categories = CategoryService.compute(root: Self.homeTree(), volume: nil)
        let sizes = categories.map(\.bytes)
        #expect(sizes == sizes.sorted(by: >))
        #expect(categories.allSatisfy { category in category.bytes > 0 })
    }

    @Test("While scanning, there is no estimated rest; afterwards it never becomes negative")
    func estimatedCategories() {
        let root = Self.homeTree()
        let whileScanning = CategoryService.compute(root: root, volume: nil)
        #expect(
            !whileScanning.contains { category in CategoryKind.estimated.contains(category.kind) })
        let tinyVolume = TestTree.volume(
            totalBytes: TestTree.big, freeBytes: 0, availableBytes: TestTree.small)
        let finished = CategoryService.compute(root: root, volume: tinyVolume)
        #expect(Self.bytes(of: .system, in: finished) == 0)
        #expect(Self.bytes(of: .purgeable, in: finished) == TestTree.small)
    }

    @Test("Each scan root is measured once, and never inside another one")
    func scanRoots() {
        let folders = ["/a", "/a/b", "/c", "/a", "/ab"]
        #expect(ScanService.withoutDuplicatesOrNesting(folders) == ["/a", "/c", "/ab"])
    }

    @Test("Rings share the circle by size, keep their branch, stop after the last ring")
    func sunburst() throws {
        let root = Node.virtualRoot()
        let unit = TestTree.big
        TestTree.folder("/a", in: root, fileBytes: 0) { area in
            TestTree.folder("one", in: area, fileBytes: unit * 3) { one in
                TestTree.chain(["two", "three", "four"], in: one, fileBytes: unit)
            }
        }
        TestTree.folder("/b", in: root, fileBytes: unit * 6)
        let segments = SunburstService.segments(of: root)
        let byName = Dictionary(
            uniqueKeysWithValues: segments.map { segment in (segment.node.name, segment) })
        #expect(segments.count == 4)  // two areas and two rings below /a; "three" is too deep
        let first = try #require(byName["/a"])
        #expect(first.start == 0 && abs(first.end - 0.5) < 1e-9)
        let one = try #require(byName["one"])
        #expect(one.ring == 1 && one.branch == first.branch)
        #expect(byName["/b"]?.branch != first.branch)
        #expect(byName["two"]?.ring == 2 && byName["three"] == nil)
        let middleOfFirst = SunburstService.innerRadius(ofRing: 0) + SunburstService.ringWidth / 2
        #expect(
            SunburstService.segment(atRadius: middleOfFirst, turn: 0.25, in: segments)?.id == "/a")
        #expect(
            SunburstService.segment(atRadius: middleOfFirst, turn: 0.75, in: segments)?.id == "/b")
        #expect(
            SunburstService.segment(
                atRadius: SunburstService.holeShare / 2, turn: 0.25, in: segments) == nil)
    }

    private static func fileEntry(_ path: String, bytes: Int64) -> Entry {
        Entry.file(FileItem(path: path, bytes: bytes))
    }

    @Test("Only files of equal size from the smallest size on can be duplicates, biggest first")
    func sameSizeGroups() {
        let big = DuplicateService.smallestBytes
        let files = [
            Self.fileEntry("/a", bytes: big), Self.fileEntry("/b", bytes: big),
            Self.fileEntry("/c", bytes: big * 2), Self.fileEntry("/d", bytes: big * 2),
            Self.fileEntry("/e", bytes: big * 3), Self.fileEntry("/f", bytes: big - 1),
            Self.fileEntry("/g", bytes: big - 1),
        ]
        let groups = DuplicateService.sameSizeGroups(files)
        #expect(
            groups.map { group in Set(group.compactMap(\.path)) } == [["/c", "/d"], ["/a", "/b"]])
    }

    @Test("Keeping one file of each duplicate group frees the size of all the others")
    func duplicateSpareBytes() {
        let big = DuplicateService.smallestBytes
        let threeCopies = ["/a", "/b", "/c"].map { path in Self.fileEntry(path, bytes: big) }
        let twoCopies = ["/d", "/e"].map { path in Self.fileEntry(path, bytes: big * 2) }
        #expect(DuplicateService.spareBytes([threeCopies, twoCopies]) == big * 4)
        #expect(DuplicateService.spareBytes([]) == 0)
    }

    @Test("A file moved to the Trash leaves its group, and a group of one file is gone")
    func duplicatesWithoutFile() {
        let big = DuplicateService.smallestBytes
        let threeCopies = ["/a", "/b", "/c"].map { path in Self.fileEntry(path, bytes: big) }
        let twoCopies = ["/d", "/e"].map { path in Self.fileEntry(path, bytes: big * 2) }
        let withoutA = DuplicateService.without("/a", in: [threeCopies, twoCopies])
        let left = DuplicateService.without("/d", in: withoutA)
        #expect(left.map { group in group.compactMap(\.path) } == [["/b", "/c"]])
    }

    @Test("Files with the same content stay together, the others and unreadable ones drop out")
    func duplicateContent() async throws {
        let folder =
            FileManager.default.temporaryDirectory.path + "/Duplicates-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: folder) }
        let size = Int(DuplicateService.smallestBytes)
        let contents = ["same1": Data(count: size), "same2": Data(count: size)]
        var different = Data(count: size)
        different[size - 1] = 1  // differs only after the sample
        for (name, data) in contents.merging(
            ["other": different], uniquingKeysWith: { first, _ in first })
        {
            FileManager.default.createFile(atPath: folder + "/" + name, contents: data)
        }
        let group = ["same1", "same2", "other", "missing"]
            .map { name in
                Self.fileEntry(folder + "/" + name, bytes: Int64(size))
            }
        let groups = await DuplicateService.confirmed([group])
        #expect(groups.map { group in Set(group.map(\.name)) } == [["same1", "same2"]])
    }

    @Test("An excluded folder covers itself and everything inside it, not a similar name")
    func excludedRoots() {
        let excluded: Set<String> = ["/a"]
        #expect(ScanService.liesIn("/a", anyOf: excluded))
        #expect(ScanService.liesIn("/a/b", anyOf: excluded))
        #expect(!ScanService.liesIn("/ab", anyOf: excluded))
    }

    @Test("Small entries the tree folds away are measured on the disk, a folder with its files")
    func allocatedBytes() throws {
        let folder =
            FileManager.default.temporaryDirectory.path + "/Allocated-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: folder) }
        let data = Data(count: Int(ScanLimits.smallestListedBytes / 4))
        FileManager.default.createFile(atPath: folder + "/one", contents: data)
        FileManager.default.createFile(atPath: folder + "/two", contents: data)
        let one = FileTreeWalker.allocatedBytes(of: folder + "/one")
        #expect(one >= Int64(data.count))
        #expect(FileTreeWalker.allocatedBytes(of: folder) == one * 2)
        #expect(FileTreeWalker.allocatedBytes(of: folder + "/missing") == 0)
    }

    @Test("A scan leaves excluded folders out with everything inside")
    func excludedScan() throws {
        let folder =
            FileManager.default.temporaryDirectory.path + "/ExcludedScan-" + UUID().uuidString
        defer { try? FileManager.default.removeItem(atPath: folder) }
        for path in ["/keep", "/skip/inner"] {
            try FileManager.default.createDirectory(
                atPath: folder + path, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: folder + path + "/file", contents: Data([1]))
        }
        let result = try #require(
            ScanService.scan(folder, excluding: [folder + "/skip"]) { _ in })
        #expect(result.root.fileCount == 1)
    }

    @Test("Unused apps are those not opened for the chosen days, the longest unused first")
    func unusedApps() {
        let now = Date()
        func app(_ name: String, daysAgo: Int?) -> AppUsage {
            AppUsage(
                path: "/Applications/\(name).app", name: name, bundleID: nil,
                lastUsed: daysAgo.map { days in FileSystem.date(daysBefore: days, now) }, bytes: 0)
        }
        let apps = [
            app("Recent", daysAgo: 5), app("Old", daysAgo: 100), app("Oldest", daysAgo: 400),
            app("Unknown", daysAgo: nil),
        ]
        let unused = AppUsageService.unused(apps, days: 90, now: now)
        #expect(unused.map(\.name) == ["Oldest", "Old"])
    }

    @Test("Disk images and installer packages count as installers, whatever the case")
    func installers() {
        for name in ["Tool.dmg", "Setup.PKG", "Old.mpkg", "Xcode.xip"] {
            #expect(CleanerService.isInstaller("/Downloads/" + name), "\(name)")
        }
        for name in ["Photo.jpg", "Notes.dmg.txt", "dmg"] {
            #expect(!CleanerService.isInstaller("/Downloads/" + name), "\(name)")
        }
    }

    @Test("Without data the summary says so; with data it mentions only what there is to say")
    func summary() {
        let empty = SummaryService.Input(
            volume: nil, categories: [], cleanableBytes: nil, copyBytes: 0, unusedAppCount: 0,
            freedBytes: 0)
        #expect(SummaryService.text(empty) == TextKey.summaryNotMeasured.translated)
        let full = SummaryService.Input(
            volume: TestTree.volume(totalBytes: 10, freeBytes: 4, availableBytes: 5),
            categories: [], cleanableBytes: 1, copyBytes: 1, unusedAppCount: 1, freedBytes: 1)
        let sentences = SummaryService.text(full)
        for key in [
            TextKey.summaryDisk, .summaryClean, .summaryCopies, .summaryApps, .summaryFreed,
        ] {
            #expect(sentences.contains(key.translated), "\(key.rawValue)")
        }
    }

    @Test("Freed space counts at most what was removed, and nothing without both readings")
    func freedBytes() {
        let removed = Self.gigabyte
        #expect(
            VolumeService.freedBytes(before: 0, after: removed / 2, removedBytes: removed)
                == removed / 2)
        #expect(
            VolumeService.freedBytes(before: 0, after: removed * 3, removedBytes: removed)
                == removed)
        #expect(VolumeService.freedBytes(before: removed, after: 0, removedBytes: removed) == 0)
        #expect(VolumeService.freedBytes(before: nil, after: removed, removedBytes: removed) == 0)
        #expect(VolumeService.freedBytes(before: 0, after: nil, removedBytes: removed) == 0)
    }

    @Test("A restart keeps how the app was started, but not a language given at the start")
    @MainActor
    func restartArguments() {
        let started = ["/App", "-demo", "YES", "-AppleLanguages", "(ar)", "-pane", "copies"]
        let kept = LifecycleService.argumentsToKeep(from: started)
        #expect(kept == ["-demo", "YES", "-pane", "copies"])
        #expect(LifecycleService.argumentsToKeep(from: ["/Applications/App"]).isEmpty)
        #expect(LifecycleService.argumentsToKeep(from: ["/App", "-AppleLanguages"]).isEmpty)
    }
}
