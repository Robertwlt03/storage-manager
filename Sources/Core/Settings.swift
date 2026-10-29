import AppKit

/// UserDefaults keys; views bind them with @AppStorage, services read them through `AppSettings`.
/// Appearance, language and units come from System Settings, so the app keeps no switches for them.
enum SettingsKey {
    static let autoScan = "autoScan"
    static let extraFolders = "extraFolders"
    static let largeFileMegabytes = "largeFileMB"
    static let unusedDays = "unusedDays"
    static let layoutMode = "layoutMode"
    static let lastScanFiles = "lastScanFiles"
    static let launchPane = "pane"  // `open … --args -pane copies`
    static let opensSettingsAtLaunch = "openSettings"  // `open … --args -openSettings YES`
    /// `open … --args -skipAccessSheet YES` (screenshots, tests)
    static let launchSkipAccessSheet = "skipAccessSheet"
    /// `open … --args -uiTest <folder>` runs the stress test.
    static let uiTestReportFolder = "uiTest"
}

enum AppSettings {
    private static var defaults: UserDefaults { .standard }

    static func registerDefaults() {
        defaults.register(defaults: [
            SettingsKey.autoScan: true,
            SettingsKey.largeFileMegabytes: LargeFileThreshold.defaultMegabytes,
            SettingsKey.unusedDays: CleanUpRules.defaultUnusedDays,
        ])
    }

    static var autoScan: Bool { defaults.bool(forKey: SettingsKey.autoScan) }
    static var largeFileMegabytes: Int { defaults.integer(forKey: SettingsKey.largeFileMegabytes) }
    static var launchPane: Pane? {
        defaults.string(forKey: SettingsKey.launchPane).flatMap(Pane.init(launchKey:))
    }
    static var opensSettingsAtLaunch: Bool {
        defaults.bool(forKey: SettingsKey.opensSettingsAtLaunch)
    }
    static var shouldSkipAccessSheet: Bool {
        defaults.bool(forKey: SettingsKey.launchSkipAccessSheet)
    }
    static var uiTestReportFolder: String? {
        defaults.string(forKey: SettingsKey.uiTestReportFolder)
    }

    /// Extra folders are stored as one string, one path per line (AppStorage cannot hold arrays).
    static func folders(from stored: String) -> [String] {
        stored.split(separator: "\n").map(String.init)
    }
    static func store(_ folders: [String]) -> String { folders.joined(separator: "\n") }
    static var extraFolders: [String] {
        folders(from: defaults.string(forKey: SettingsKey.extraFolders) ?? "")
    }
}

/// Languages the app ships; the raw value is the name of the `.lproj` folder. Which one is used
/// comes from macOS, which also allows a language per app (System Settings › General › Language &
/// Region › Applications).
nonisolated enum AppLanguage: String, CaseIterable {
    case de, en, fr, es, it, nl
    case ptBR = "pt-BR"
    case sv, da, nb, fi, pl, cs, tr, ru, uk, ja, ko
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    static let fallback = AppLanguage.en

    /// The first preferred system language the app supports.
    static var current: AppLanguage {
        Locale.preferredLanguages.lazy.compactMap(match).first ?? fallback
    }

    /// Maps a system language like "zh-TW", "pt-PT" or "no" to one of the shipped languages.
    static func match(_ identifier: String) -> AppLanguage? {
        let language = Locale.Language(identifier: identifier)
        guard let code = language.languageCode?.identifier else { return nil }
        switch code {
        case "zh": return language.maximalIdentifier.contains("Hant") ? .zhHant : .zhHans
        case "pt": return .ptBR
        case "no", "nn": return .nb
        default: return AppLanguage(rawValue: code)
        }
    }
}

enum LayoutMode: Int, CaseIterable, Identifiable {
    case list, grid
    var id: Self { self }
    var title: TextKey { self == .list ? .layoutList : .layoutGrid }
}
