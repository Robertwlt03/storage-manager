import Foundation
import Testing

@testable import StorageManager

/// The legend under the storage bar.
@Suite("Storage legend")
struct LegendTests {
    private static func category(_ index: Int) -> StorageSegment {
        StorageSegment(
            id: "category\(index)", title: "Category \(index)", bytes: 1, colorIndex: index)
    }

    private static let free = StorageSegment(id: "free", title: "Free", bytes: 1, colorIndex: nil)
    private static let uncovered = StorageSegment(
        id: StorageSegment.usedID, title: "Used", bytes: 1, colorIndex: 0)

    @Test("A short legend shows every category, then the uncovered and the free space")
    func shortLegend() {
        let segments = [Self.category(0), Self.uncovered, Self.category(1), Self.free]
        let legend = StorageSegment.legend(of: segments)
        #expect(legend.map(\.id) == ["category0", "category1", StorageSegment.usedID, "free"])
    }

    @Test("A long legend still names every category, so each one can be opened")
    func longLegend() {
        let categoryCount = 12
        let categories = (0..<categoryCount).map(Self.category)
        let legend = StorageSegment.legend(of: categories + [Self.free])
        #expect(legend.map(\.id) == categories.map(\.id) + ["free"])
    }
}
