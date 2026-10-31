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

    @Test("A volume runs low below a share of its capacity, but never above the fixed amount")
    func lowSpace() {
        let total = 100 * Self.gigabyte
        let limit = Int64(Double(total) * LowSpace.warningShare)
        func volume(available: Int64, total: Int64 = total) -> VolumeInformation {
            VolumeInformation(
                path: "/", name: "Disk", format: "APFS", totalBytes: total, freeBytes: available,
                availableBytes: available, isInternal: true, isRoot: true)
        }
        #expect(volume(available: limit - 1).isLow)
        #expect(!volume(available: limit).isLow)
        let bigDisk = LowSpace.largestWarningBytes * 100
        #expect(!volume(available: LowSpace.largestWarningBytes, total: bigDisk).isLow)
        #expect(volume(available: LowSpace.largestWarningBytes - 1, total: bigDisk).isLow)
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

    @Test("Rings are offered only on Folders, and pages without layouts only have a list")
    func layoutChoices() {
        #expect(PageLayout.choices(on: .explorer) == [.list, .grid, .rings])
        #expect(PageLayout.choices(on: .largeFiles) == [.list, .grid])
        #expect(PageLayout.choices(on: .cleaner) == [.list])
    }

    @Test("Rings show only on Folders; every other page keeps the stored list or tiles")
    func shownLayout() {
        #expect(PageLayout.shown(on: .explorer, layoutMode: .grid, showsRings: true) == .rings)
        #expect(PageLayout.shown(on: .apps, layoutMode: .grid, showsRings: true) == .grid)
        #expect(PageLayout.shown(on: nil, layoutMode: .list, showsRings: true) == .list)
        #expect(PageLayout.shown(on: .explorer, layoutMode: .list, showsRings: false) == .list)
    }

    @Test("Choosing a layout leaves rings alone off Folders and keeps the list or tiles for rings")
    func chosenLayout() {
        let tilesOnApps = PageLayout.grid.stored(on: .apps, layoutMode: .list, showsRings: true)
        #expect(tilesOnApps == (.grid, true))
        let listOnFolders = PageLayout.list.stored(
            on: .explorer, layoutMode: .grid, showsRings: true)
        #expect(listOnFolders == (.list, false))
        let ringsOnFolders = PageLayout.rings.stored(
            on: .explorer, layoutMode: .grid, showsRings: false)
        #expect(ringsOnFolders == (.grid, true))
        // The View menu during a search has no page, and leaves the rings of Folders alone.
        #expect(
            PageLayout.grid.stored(on: nil, layoutMode: .list, showsRings: true) == (.grid, true))
    }

    @Test("Large-file thresholds are counted in decimal megabytes, like Finder")
    func largeFileThreshold() {
        #expect(LargeFileThreshold.bytes(1) == 1_000_000)
        #expect(LargeFileThreshold.megabyteOptions.contains(LargeFileThreshold.defaultMegabytes))
    }
}
