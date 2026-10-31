import Foundation
import Testing

@testable import StorageManager

/// The demo shows every page with made-up data and must never touch the disk.
@Suite("Demo mode", .serialized)
struct DemoTests {
    private static let unusedDays = 90

    private static func demoModel() -> AppModel {
        UserDefaults.standard.set(true, forKey: SettingsKey.launchDemo)
        defer { UserDefaults.standard.removeObject(forKey: SettingsKey.launchDemo) }
        let model = AppModel()
        model.launch()
        return model
    }

    @Test("Every page gets something to show")
    func fillsEveryPage() {
        let model = Self.demoModel()
        #expect(model.isDemo)
        #expect(model.hasData)
        #expect(!model.categories.isEmpty)
        #expect(model.statistics != nil)
        #expect(model.startupVolume != nil)
        #expect(AppUsageService.unused(model.apps, days: Self.unusedDays).count == 2)
        #expect(model.copyGroups.count == 1)
        #expect(model.cleanItems?.count == CleanKind.allCases.count)
    }

    @Test("The report holds the summary, every category and the largest files")
    func report() {
        let model = Self.demoModel()
        let report = model.report()
        #expect(report.contains(model.summary(unusedDays: AppSettings.unusedDays)))
        for category in model.categories {
            #expect(report.contains(category.kind.title.translated))
        }
        #expect(report.contains("Holiday 2025.mov"))
        #expect(report.hasSuffix("\n"))
    }

    @Test("Leaving the search clears it, and canceling without a running scan changes nothing")
    func searchAndCancel() {
        let model = Self.demoModel()
        model.searchText = "report"
        model.isSearchPresented = true
        model.endSearch()
        #expect(model.searchText.isEmpty && !model.isSearchPresented)
        model.cancelScan()
        #expect(!model.isScanning && model.hasData)
    }

    @Test("Nothing is scanned or removed, and the demo's clean-up paths do not exist")
    func touchesNothing() async throws {
        let model = Self.demoModel()
        let items = try #require(model.cleanItems)
        for path in items.flatMap(\.paths) {
            #expect(!FileManager.default.fileExists(atPath: path))
        }
        let result = await model.clean(items)
        #expect(result.freed == 0 && result.failed == 0)
        let group = try #require(model.copyGroups.first)
        #expect(try await model.delete(group) == 0)
        model.scan()
        #expect(!model.isScanning)
        #expect(model.copyGroups.count == 1)
    }
}
