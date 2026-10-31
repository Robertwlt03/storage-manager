import Foundation
import Testing

@testable import StorageWidget

/// The widget's figures, checked without WidgetKit drawing anything.
@Suite("Widget")
struct WidgetTests {
    private static let total: Int64 = 1_000

    @Test("The used share stays between none and all")
    func usedShare() {
        #expect(VolumeSpace(availableBytes: 250, totalBytes: Self.total).usedShare == 0.75)
        #expect(VolumeSpace(availableBytes: Self.total * 2, totalBytes: Self.total).usedShare == 0)
        #expect(VolumeSpace(availableBytes: -1, totalBytes: Self.total).usedShare == 1)
        #expect(VolumeSpace(availableBytes: 0, totalBytes: 0).usedShare == 0)
    }

    @Test("The widget reads the startup volume")
    func startupVolume() throws {
        let space = try #require(VolumeSpace.startup())
        #expect(space.totalBytes > 0 && space.availableBytes <= space.totalBytes)
    }
}
