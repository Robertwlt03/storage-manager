import Foundation
import Testing

@testable import StorageManager

/// The decisions the services make from a scanned tree, checked on hand-built trees.
@Suite("Services")
struct ServiceTests {
    private static let gigabyte: Int64 = 1_000_000_000

    /// The home folder with Downloads, Library/Caches and a folder no category names.
    private static func homeTree() -> Node {
        let root = Node.virtualRoot()
        TestTree.folder(Paths.home, in: root) { home in
            TestTree.folder("Downloads", in: home)
            TestTree.folder("Library", in: home) { library in
                TestTree.folder("Caches", in: library)
            }
            TestTree.folder("Projects", in: home)
        }
        return root
    }

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

    @Test("Size classes sort every file by its size, and folded files count as the smallest")
    func sizeClasses() {
        let root = Node.virtualRoot()
        TestTree.folder("/scan", in: root, fileBytes: TestTree.small) { scan in
            TestTree.folder("film", in: scan, fileBytes: 2 * Self.gigabyte)
        }
        let statistics = StatisticsService.compute(root: root, largeFileBytes: Self.gigabyte)
        let bySizeClass = Dictionary(
            uniqueKeysWithValues: statistics.sizeClasses.map { row in (row.sizeClass, row.count) })
        #expect(bySizeClass[.under1MB] == 1)
        #expect(bySizeClass[.over1GB] == 1)
        #expect(statistics.largeFileCount == 1)
        #expect(statistics.fileCount == 2)
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

    @Test("Without data the summary says so; with data it mentions only what there is to say")
    func summary() {
        let empty = SummaryService.Input(
            volume: nil, categories: [], cleanableBytes: nil, copyBytes: 0, unusedAppCount: 0)
        #expect(SummaryService.text(empty) == TextKey.summaryNotMeasured.translated)
        let full = SummaryService.Input(
            volume: TestTree.volume(totalBytes: 10, freeBytes: 4, availableBytes: 5),
            categories: [], cleanableBytes: 1, copyBytes: 1, unusedAppCount: 1)
        let sentences = SummaryService.text(full)
        for key in [TextKey.summaryDisk, .summaryClean, .summaryCopies, .summaryApps] {
            #expect(sentences.contains(key.translated), "\(key.rawValue)")
        }
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
