import Foundation
import Testing

@testable import StorageManager

/// Small rules of the models and pages that the views rely on.
@Suite("Models and pages")
struct ModelTests {
    private static let gigabyte: Int64 = 1_000_000_000

    @Test("Emptying the Trash and removing installers need a deliberate click in the cleaner")
    func cleanerPreselection() {
        let preselected = CleanKind.allCases.filter(\.isPreselected)
        #expect(Set(preselected) == Set(CleanKind.allCases).subtracting([.trash, .installers]))
    }

    @Test("Used and purgeable space never become negative")
    func volumeSpace() {
        let volume = VolumeInformation(
            path: "/", name: "Disk", format: "APFS", totalBytes: 10 * Self.gigabyte,
            freeBytes: 12 * Self.gigabyte, availableBytes: 11 * Self.gigabyte,
            isInternal: true, isRoot: true)
        #expect(volume.usedBytes == 0)
        #expect(volume.purgeableBytes == 0)
    }

    @Test("Every page has its own launch key, and a launch key leads back to its page")
    func launchKeys() {
        let keys = Pane.everyPage.map(\.launchKey)
        #expect(Set(keys).count == keys.count)
        for page in Pane.everyPage {
            #expect(Pane(launchKey: page.launchKey) == page)
        }
        #expect(Pane(launchKey: "/Volumes/Backup") == .volume("/Volumes/Backup"))
        #expect(Pane(launchKey: "unknown") == nil)
    }

    @Test("Large-file thresholds are counted in decimal megabytes, like Finder")
    func largeFileThreshold() {
        #expect(LargeFileThreshold.bytes(1) == 1_000_000)
        #expect(LargeFileThreshold.megabyteOptions.contains(LargeFileThreshold.defaultMegabytes))
    }
}
