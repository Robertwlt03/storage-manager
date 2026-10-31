import AppKit

/// UserDefaults keys; views bind them with @AppStorage, services read them through `AppSettings`.
/// Appearance, language and units come from System Settings, so the app keeps no switches for them.
enum SettingsKey {
    static let scansAutomatically = "autoScan"
    static let extraFolders = "extraFolders"
    static let showsMenuBarItem = "showsMenuBarItem"
    static let showsAdvancedPages = "showsAdvancedPages"
    static let excludedFolders = "excludedFolders"
    static let largeFileMegabytes = "largeFileMB"
    static let unusedDays = "unusedDays"
    static let layoutMode = "layoutMode"
    static let showsRings = "showsRings"  // the Folders page as rings instead of a table
    static let lastScanFiles = "lastScanFiles"
    /// The used space after each full scan, and the folder sizes of the last two (HistoryStore).
    static let historyPoints = "historyPoints"
    static let latestFolderSizes = "latestFolderSizes"
    static let previousFolderSizes = "previousFolderSizes"
    /// What clean-ups and deleted copies really freed, all together.
    static let totalFreedBytes = "totalFreedBytes"
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
    /// macOS's own key for an app's languages, which its per-app language setting writes too.
    nonisolated static let appLanguages = "AppleLanguages"
}

enum AppSettings {
    private static var defaults: UserDefaults { .standard }

    static func registerDefaults() {
        defaults.register(defaults: [
            SettingsKey.scansAutomatically: true,
            SettingsKey.showsMenuBarItem: true,
            SettingsKey.largeFileMegabytes: LargeFileThreshold.defaultMegabytes,
            SettingsKey.unusedDays: CleanUpRules.defaultUnusedDays,
        ])
    }

    static var scansAutomatically: Bool { defaults.bool(forKey: SettingsKey.scansAutomatically) }
    static var showsMenuBarItem: Bool { defaults.bool(forKey: SettingsKey.showsMenuBarItem) }
    static var largeFileMegabytes: Int { defaults.integer(forKey: SettingsKey.largeFileMegabytes) }
    static var unusedDays: Int { defaults.integer(forKey: SettingsKey.unusedDays) }
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
    static var excludedFolders: [String] {
        folders(from: defaults.string(forKey: SettingsKey.excludedFolders) ?? "")
    }
}

/// Languages the app ships; the raw value is the name of the `.lproj` folder. Which one is used
/// comes from macOS, unless one is picked in the app's settings (the same as macOS's language per
/// app under System Settings › General › Language & Region › Applications).
nonisolated enum AppLanguage: String, CaseIterable {
    case german = "de"
    case english = "en"
    case french = "fr"
    case spanish = "es"
    case italian = "it"
    case dutch = "nl"
    case brazilianPortuguese = "pt-BR"
    case europeanPortuguese = "pt-PT"
    case swedish = "sv"
    case danish = "da"
    case norwegian = "nb"
    case finnish = "fi"
    case polish = "pl"
    case czech = "cs"
    case hungarian = "hu"
    case romanian = "ro"
    case greek = "el"
    case turkish = "tr"
    case russian = "ru"
    case ukrainian = "uk"
    case japanese = "ja"
    case korean = "ko"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case indonesian = "id"
    case vietnamese = "vi"
    case thai = "th"
    case hindi = "hi"

    static let fallback = AppLanguage.english

    /// The language picked in the app's settings, nil while it follows the Mac. Only the app's own
    /// settings count, as the Mac's languages stand under the same key in the global ones.
    static var chosen: AppLanguage? {
        let ownSettings = UserDefaults.standard.persistentDomain(
            forName: Bundle.main.bundleIdentifier ?? "")
        let languages = ownSettings?[SettingsKey.appLanguages] as? [String]
        return languages?.first.flatMap(match)
    }

    /// Takes effect at the next launch, as macOS reads the languages once when the app starts.
    static func choose(_ language: AppLanguage?) {
        if let language {
            UserDefaults.standard.set([language.rawValue], forKey: SettingsKey.appLanguages)
        } else {
            UserDefaults.standard.removeObject(forKey: SettingsKey.appLanguages)
        }
    }

    /// The language's name in itself, such as "Deutsch" or "日本語", so everyone finds their own.
    var nativeName: String {
        let locale = Locale(identifier: rawValue)
        let name = locale.localizedString(forIdentifier: rawValue) ?? rawValue
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }

    /// Every language, sorted by its own name.
    static var byNativeName: [AppLanguage] {
        allCases.sorted { left, right in
            left.nativeName.localizedStandardCompare(right.nativeName) == .orderedAscending
        }
    }

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
        case "pt":
            // Plain "pt" is Brazilian on Apple's systems; Portugal and the other countries get
            // Portugal's Portuguese.
            let region = language.region?.identifier
            return region == nil || region == "BR" ? .brazilianPortuguese : .europeanPortuguese
        case "no", "nn": return .norwegian
        default: return AppLanguage(rawValue: code)
        }
    }
}

enum LayoutMode: Int {
    case list, grid
}

/// The choices of the layout switch: list and tiles on every page with layouts, rings only on
/// Folders. List and tiles are stored as `LayoutMode` for all pages, rings as a switch of their
/// own.
enum PageLayout: CaseIterable, Identifiable {
    case list, grid, rings
    var id: Self { self }

    var title: TextKey {
        switch self {
        case .list: .layoutList
        case .grid: .layoutGrid
        case .rings: .rings
        }
    }

    var symbol: String {
        switch self {
        case .list: Symbols.list
        case .grid: Symbols.grid
        case .rings: Symbols.rings
        }
    }

    /// The stored mode behind this choice; rings keep the mode the other pages use.
    private var layoutMode: LayoutMode? {
        switch self {
        case .list: .list
        case .grid: .grid
        case .rings: nil
        }
    }

    /// What a page can show: tiles where it has layouts, rings on Folders, otherwise only a list.
    /// Search results (no page) have list and tiles.
    static func choices(on pane: Pane?) -> [PageLayout] {
        if pane?.supportsGrid == false { return [.list] }
        return pane?.supportsRings == true ? allCases : [.list, .grid]
    }

    /// The settings to store when this layout is chosen on a page: rings change only where they
    /// are offered, so tiles on another page leave Folders as it was, and rings keep the list or
    /// tiles the other pages use.
    func stored(on pane: Pane?, layoutMode: LayoutMode, showsRings: Bool) -> (
        layoutMode: LayoutMode, showsRings: Bool
    ) {
        (self.layoutMode ?? layoutMode, pane?.supportsRings == true ? self == .rings : showsRings)
    }

    /// What a page shows with the stored settings; tiles and rings count only where they are
    /// offered.
    static func shown(on pane: Pane?, layoutMode: LayoutMode, showsRings: Bool) -> PageLayout {
        if pane?.supportsGrid == false { return .list }
        if showsRings && pane?.supportsRings == true { return .rings }
        return layoutMode == .grid ? .grid : .list
    }
}
