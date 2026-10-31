import AppKit

/// UserDefaults keys; views bind them with @AppStorage, services read them through `AppSettings`.
/// Appearance, language and units come from System Settings, so the app keeps no switches for them.
enum SettingsKey {
    static let scansAutomatically = "autoScan"
    static let extraFolders = "extraFolders"
    static let largeFileMegabytes = "largeFileMB"
    static let unusedDays = "unusedDays"
    static let layoutMode = "layoutMode"
    static let lastScanFiles = "lastScanFiles"
    static let launchPane = "pane"  // `open … --args -pane copies`
    static let opensSettingsAtLaunch = "openSettings"  // `open … --args -openSettings YES`
    /// `open … --args -skipAccessSheet YES` (screenshots, tests)
    static let launchSkipAccessSheet = "skipAccessSheet"
    /// `open … --args -demo YES` shows made-up data instead of measuring (see DemoData).
    static let launchDemo = "demo"
    /// `open … --args -uiTest <folder>` runs the stress test.
    static let uiTestReportFolder = "uiTest"
    /// `open … --args -appearance dark` (or `light`) overrides System Settings, for snapshots.
    static let launchAppearance = "appearance"
}

enum AppSettings {
    private static var defaults: UserDefaults { .standard }

    static func registerDefaults() {
        defaults.register(defaults: [
            SettingsKey.scansAutomatically: true,
            SettingsKey.largeFileMegabytes: LargeFileThreshold.defaultMegabytes,
            SettingsKey.unusedDays: CleanUpRules.defaultUnusedDays,
        ])
    }

    static var scansAutomatically: Bool { defaults.bool(forKey: SettingsKey.scansAutomatically) }
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
    static var showsDemo: Bool { defaults.bool(forKey: SettingsKey.launchDemo) }
    static var uiTestReportFolder: String? {
        defaults.string(forKey: SettingsKey.uiTestReportFolder)
    }
    static var launchAppearance: NSAppearance? {
        switch defaults.string(forKey: SettingsKey.launchAppearance) {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil  // follows System Settings
        }
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
    case german = "de"
    case english = "en"
    case french = "fr"
    case spanish = "es"
    case italian = "it"
    case dutch = "nl"
    case brazilianPortuguese = "pt-BR"
    case swedish = "sv"
    case danish = "da"
    case norwegian = "nb"
    case finnish = "fi"
    case polish = "pl"
    case czech = "cs"
    case turkish = "tr"
    case russian = "ru"
    case ukrainian = "uk"
    case japanese = "ja"
    case korean = "ko"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    static let fallback = AppLanguage.english

    /// The first preferred system language the app supports.
    static var current: AppLanguage {
        Locale.preferredLanguages.lazy.compactMap(match).first ?? fallback
    }

    /// Maps a system language like "zh-TW", "pt-PT" or "no" to one of the shipped languages.
    static func match(_ identifier: String) -> AppLanguage? {
        let language = Locale.Language(identifier: identifier)
        guard let code = language.languageCode?.identifier else { return nil }
        switch code {
        case "zh":
            let isTraditional = language.maximalIdentifier.contains("Hant")
            return isTraditional ? .traditionalChinese : .simplifiedChinese
        case "pt": return .brazilianPortuguese
        case "no", "nn": return .norwegian
        default: return AppLanguage(rawValue: code)
        }
    }
}

enum LayoutMode: Int, CaseIterable, Identifiable {
    case list, grid
    var id: Self { self }
    var title: TextKey { self == .list ? .layoutList : .layoutGrid }
}
