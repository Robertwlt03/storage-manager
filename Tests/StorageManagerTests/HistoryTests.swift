import Foundation
import Testing

@testable import StorageManager

/// The storage history: which points are kept, which folders are compared and which growth is
/// listed.
@Suite("History")
struct HistoryTests {
    private static let megabyte: Int64 = 1_000_000
    private static let earlierDate = Date(timeIntervalSince1970: 0)
    private static let laterDate = Date(timeIntervalSince1970: 86_400)

    private static let areas = ["/a", "/c"]

    private static func sizes(
        _ bytes: [String: Int64], at date: Date, areas: [String] = areas, hadFullAccess: Bool = true
    ) -> FolderSizes {
        FolderSizes(date: date, areas: areas, hadFullAccess: hadFullAccess, bytes: bytes)
    }

    /// Each folder inside the one before.
    private static func chain(_ names: ArraySlice<String>, in parent: Node, fileBytes: Int64) {
        guard let name = names.first else { return }
        TestTree.folder(name, in: parent, fileBytes: fileBytes) { folder in
            chain(names.dropFirst(), in: folder, fileBytes: fileBytes)
        }
    }

    @Test("Only the newest points are kept")
    func keptPoints() {
        let full = (0..<HistoryService.keptPoints)
            .map { day in
                HistoryPoint(date: Date(timeIntervalSince1970: Double(day)), usedBytes: Int64(day))
            }
        let newest = HistoryPoint(date: Self.laterDate, usedBytes: -1)
        let points = HistoryService.adding(newest, to: full)
        #expect(points.count == HistoryService.keptPoints)
        #expect(points.last == newest)
        #expect(points.first == full[1])
    }

    @Test("Folders are compared down to the set depth and from the smallest compared size")
    func folderSizes() {
        let root = Node.virtualRoot()
        let enough = HistoryService.smallestComparedBytes
        TestTree.folder("/area", in: root, fileBytes: enough) { area in
            TestTree.folder("tiny", in: area, fileBytes: enough / 2)
            Self.chain(["one", "two", "three", "four"], in: area, fileBytes: enough)
        }
        let sizes = HistoryService.folderSizes(of: root, at: Self.laterDate, hadFullAccess: true)
        #expect(sizes.date == Self.laterDate)
        #expect(sizes.areas == ["/area"])
        #expect(
            Set(sizes.bytes.keys)
                == ["/area", "/area/one", "/area/one/two", "/area/one/two/three"])
        #expect(sizes.bytes["/area/one/two/three"] == enough * 2)
    }

    @Test("Small growth is left out, new folders count from zero, a subfolder can explain growth")
    func growth() throws {
        let earlier = Self.sizes(
            ["/a": 1_000 * Self.megabyte, "/a/b": 500 * Self.megabyte, "/c": 200 * Self.megabyte],
            at: Self.earlierDate)
        let later = Self.sizes(
            [
                "/a": 2_000 * Self.megabyte, "/a/b": 1_400 * Self.megabyte,
                "/c": 250 * Self.megabyte, "/new": 300 * Self.megabyte,
            ], at: Self.laterDate)
        let growth = try #require(HistoryService.growth(from: earlier, to: later))
        #expect(growth.since == Self.earlierDate)
        #expect(growth.folders.map(\.path) == ["/a/b", "/new"])
        #expect(growth.folders.first?.grownBytes == 900 * Self.megabyte)
    }

    @Test("A subfolder explaining less than the set share keeps its parent listed")
    func partlyExplained() throws {
        let earlier = Self.sizes([:], at: Self.earlierDate)
        let later = Self.sizes(
            ["/a": 1_000 * Self.megabyte, "/a/b": 500 * Self.megabyte], at: Self.laterDate)
        let growth = try #require(HistoryService.growth(from: earlier, to: later))
        #expect(growth.folders.map(\.path) == ["/a", "/a/b"])
    }

    @Test("Only the biggest growth is listed")
    func listedFolders() throws {
        let count = HistoryService.listedFolders + 2
        let bytes = Dictionary(
            uniqueKeysWithValues: (1...count)
                .map { index in
                    ("/folder\(index)", Int64(index) * 200 * Self.megabyte)
                })
        let growth = try #require(
            HistoryService.growth(
                from: Self.sizes([:], at: Self.earlierDate),
                to: Self.sizes(bytes, at: Self.laterDate)))
        #expect(growth.folders.count == HistoryService.listedFolders)
        #expect(growth.folders.first?.path == "/folder\(count)")
    }

    @Test("Scans of different areas or with different access are not compared")
    func notComparable() {
        let earlier = Self.sizes([:], at: Self.earlierDate)
        let later = ["/a": 1_000 * Self.megabyte]
        #expect(
            HistoryService.growth(
                from: earlier, to: Self.sizes(later, at: Self.laterDate, areas: ["/a"])) == nil)
        #expect(
            HistoryService.growth(
                from: earlier, to: Self.sizes(later, at: Self.laterDate, hadFullAccess: false))
                == nil)
    }

    @Test("The store keeps the points and compares the two newest folder lists")
    func store() throws {
        let suite = "HistoryTests.store"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HistoryStore(defaults: defaults)
        let point = HistoryPoint(date: Self.laterDate, usedBytes: Self.megabyte)
        store.record([point], latest: Self.sizes([:], at: Self.earlierDate))
        #expect(store.growth == nil)
        store.record([point], latest: Self.sizes(["/a": 500 * Self.megabyte], at: Self.laterDate))
        #expect(store.points == [point])
        #expect(store.growth?.since == Self.earlierDate)
        #expect(store.growth?.folders.map(\.path) == ["/a"])
    }
}
