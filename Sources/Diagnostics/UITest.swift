import AppKit
import SwiftUI

/// `open … --args -uiTest <folder>`: drives the running app like a very fast user and tries to break it.
/// It switches pages and views during scans, cancels and restarts scans, flips settings, digs into folders and
/// searches, checks the data after every step and saves a picture of the window. It never deletes, cleans up or
/// moves anything to the Trash, prints only counts (no names) and restores the user's settings at the end.
@MainActor enum UITest {
    private static let settingKeys = [SettingsKey.layoutMode, SettingsKey.largeFileMB, SettingsKey.unusedDays]
    private static var problems: [String] = []
    private static var steps = 0
    private static var folder = URL(fileURLWithPath: NSTemporaryDirectory())

    static func run(_ model: AppModel, into dir: String) async {
        folder = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let saved = settingKeys.map { ($0, UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?[$0]) }
        defer { restore(saved) }
        log("Start, Vollzugriff: \(model.hasFullDiskAccess)")

        await chaosDuringScan(model)
        await cancelAndRestart(model)
        await waitForScan(model)
        await visitEverything(model)
        await digIntoFolders(model)
        await search(model)
        await flipSettings(model)
        await rescanOnOverview(model)

        log(problems.isEmpty ? "ERGEBNIS: keine Fehler in \(steps) Schritten" : "ERGEBNIS: \(problems.count) Probleme")
        problems.forEach { log("PROBLEM: \($0)") }
    }

    // MARK: Scenarios

    /// Jump between pages, layouts and searches while the first scan is still running.
    private static func chaosDuringScan(_ model: AppModel) async {
        if !model.scanning { model.scan() }
        for round in 0..<3 {
            for pane in allPanes(model) {
                model.pane = pane
                set(SettingsKey.layoutMode, (round + steps) % 2)
                model.searchText = steps % 5 == 0 ? "a" : ""
                await step("Chaos \(round) \(pane.launchKey)", model, wait: 0.25, picture: false)
            }
        }
        model.searchText = ""
    }

    /// Cancel and restart scans in quick succession, also twice in a row.
    private static func cancelAndRestart(_ model: AppModel) async {
        model.cancelScan(); await step("Abbruch", model, wait: 0.3)
        model.cancelScan(); await step("Doppelter Abbruch", model, wait: 0.2)
        model.scan(); model.scan(); await step("Doppelter Start", model, wait: 1)
        model.cancelScan(); model.scan(); await step("Abbruch und sofort neu", model, wait: 0.5)
        check(model.scanning, "Messung läuft nach Neustart nicht")
    }

    private static func waitForScan(_ model: AppModel) async {
        let start = Date()
        while model.scanning && Date().timeIntervalSince(start) < 240 { try? await Task.sleep(for: .milliseconds(500)) }
        check(!model.scanning, "Messung nach 4 Minuten nicht fertig")
        log("Messung fertig nach \(Int(Date().timeIntervalSince(start))) s: \(model.root.fileCount) Dateien, \(model.categories.count) Kategorien")
        await step("Nach der Messung", model, wait: 1)
    }

    /// Every page in light and dark, as list and as grid, with a picture of each.
    private static func visitEverything(_ model: AppModel) async {
        for appearance in [NSAppearance(named: .aqua), NSAppearance(named: .darkAqua)] {
            NSApp.appearance = appearance  // only for this test run; the app itself follows the system
            for pane in allPanes(model) {
                for layout in LayoutMode.allCases where layout == .list || pane.supportsGrid {
                    set(SettingsKey.layoutMode, layout.rawValue)
                    model.pane = pane
                    await step("Seite \(pane.launchKey) \(appearance?.name.rawValue ?? "") \(layout)", model, wait: 0.8)
                }
            }
        }
        set(SettingsKey.layoutMode, LayoutMode.list.rawValue)
        NSApp.appearance = nil
    }

    /// Open every category, go five levels deep, back out, and repeat quickly.
    private static func digIntoFolders(_ model: AppModel) async {
        for category in model.categories {
            guard let node = category.node else { continue }
            model.open(node)
            var current = node
            for _ in 0..<5 {
                guard let next = current.children.first else { break }
                model.explorerPath.append(next)
                current = next
                await step("Ordner tiefer", model, wait: 0.15, picture: false)
            }
            while !model.explorerPath.isEmpty { model.explorerPath.removeLast() }
            await step("Ordner zurück", model, wait: 0.15, picture: false)
        }
    }

    private static func search(_ model: AppModel) async {
        for query in ["a", "lib", "zzzzqq", " ", "e", ""] {
            for scope in SearchScope.allCases {
                model.searchScope = scope
                model.searchText = query
                await step("Suche", model, wait: 0.4, picture: false)
                let hits = SearchService.search(query, scope: scope, in: model.root)
                check(hits.count <= ScanConfig.searchLimit, "Suche liefert mehr als die Grenze")
                check(scope != .folders || hits.allSatisfy(\.isFolder), "Ordnersuche liefert Dateien")
            }
        }
        model.searchText = ""
    }

    /// Thresholds and day ranges, each on the page that shows it.
    private static func flipSettings(_ model: AppModel) async {
        model.pane = .largeFiles
        for mb in LargeFileThreshold.optionsMB {
            set(SettingsKey.largeFileMB, mb)
            await step("Große Dateien \(mb)", model, wait: 0.3, picture: false)
        }
        model.pane = .apps
        for days in CleanConfig.unusedDayOptions {
            set(SettingsKey.unusedDays, days)
            await step("Tage \(days)", model, wait: 0.3, picture: false)
        }
        model.pane = .cleaner
        for _ in 0..<3 { model.refreshCleanItems() }
        await step("Aufräumen neu suchen", model, wait: 0.5)
    }

    /// The scenario that crashed Swift Charts: rescan while the page with the chart is open, then switch around.
    private static func rescanOnOverview(_ model: AppModel) async {
        model.pane = .overview
        model.scan()
        for pane in allPanes(model) + [.overview, .explorer, .overview] {
            model.pane = pane
            await step("Neu messen \(pane.launchKey)", model, wait: 0.3, picture: false)
        }
        await waitForScan(model)
        model.pane = .overview
        await step("Überblick am Ende", model, wait: 1)
    }

    // MARK: Helpers

    private static func allPanes(_ model: AppModel) -> [Pane] {
        Pane.main + Pane.tidy + Pane.system + model.volumes.filter { !$0.isRoot }.map { .volume($0.path) }
    }

    private static func step(_ name: String, _ model: AppModel, wait seconds: Double, picture: Bool = true) async {
        steps += 1
        try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
        checkData(model, name)
        if picture { snapshot(String(format: "%03d", steps)) }
        log("\(steps) \(name) ok")
    }

    /// Consistency of what every page shows.
    private static func checkData(_ model: AppModel, _ name: String) {
        let cats = model.categories
        check(zip(cats, cats.dropFirst()).allSatisfy { $0.bytes >= $1.bytes }, "\(name): Kategorien nicht sortiert")
        check(cats.allSatisfy { $0.bytes >= 0 }, "\(name): negative Größe")
        check((0...1).contains(model.scanFraction), "\(name): Fortschritt außerhalb 0–100 %")
        check(model.root.bytes >= 0 && model.root.fileCount >= 0, "\(name): Baum ungültig")
        if !model.explorerPath.isEmpty {
            check(zip(model.explorerPath, model.explorerPath.dropFirst()).allSatisfy { $1.path.hasPrefix($0.path) },
                  "\(name): Ordnerpfad passt nicht zusammen")
        }
    }

    private static func check(_ ok: Bool, _ message: String) { if !ok { problems.append(message) } }

    private static func set(_ key: String, _ value: Any) { UserDefaults.standard.set(value, forKey: key) }

    private static func restore(_ saved: [(String, Any?)]) {
        for (key, value) in saved {
            if let value { UserDefaults.standard.set(value, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
        }
    }

    private static func snapshot(_ name: String) {
        guard let view = NSApp.windows.first(where: { $0.isVisible && $0.frame.width > 600 })?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent(name + ".png"))
    }

    private static func log(_ text: String) {
        print("[UITest] \(Date().formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3)))) \(text)")
        fflush(stdout)
    }
}
