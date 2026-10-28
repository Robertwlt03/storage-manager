import AppKit

/// UserDefaults keys; views bind them with @AppStorage, services read them through `AppSettings`.
enum SettingsKey {
    static let language = "language"
    static let appearance = "appearance"
    static let palette = "palette"
    static let binaryUnits = "binaryUnits"
    static let autoScan = "autoScan"
    static let eco = "eco"
    static let pauseOnLowPower = "pauseOnLowPower"
    static let largeFileMB = "largeFileMB"
    static let extraFolders = "extraFolders"
    static let layoutMode = "layoutMode"
    static let unusedDays = "unusedDays"
    static let lastScanFiles = "lastScanFiles"
    static let launchPane = "pane"  // `open … --args -pane copies`
    static let launchSettings = "openSettings"  // `open … --args -openSettings YES`
    static let launchSkipAccess = "skipAccessSheet"
    static let launchUITest = "uiTest"  // `open … --args -uiTest <folder>` runs the stress test  // `open … --args -skipAccessSheet YES` (screenshots, tests)
}

enum AppSettings {
    private static var d: UserDefaults { .standard }

    static func registerDefaults() {
        d.register(defaults: [SettingsKey.autoScan: true, SettingsKey.eco: true, SettingsKey.pauseOnLowPower: true,
                              SettingsKey.largeFileMB: LargeFileThreshold.defaultMB,
                              SettingsKey.unusedDays: CleanConfig.defaultUnusedDays])
    }

    static var autoScan: Bool { d.bool(forKey: SettingsKey.autoScan) }
    static var eco: Bool { d.bool(forKey: SettingsKey.eco) }
    static var pauseOnLowPower: Bool { d.bool(forKey: SettingsKey.pauseOnLowPower) }
    static var binaryUnits: Bool { d.bool(forKey: SettingsKey.binaryUnits) }
    static var language: AppLanguage { AppLanguage(rawValue: d.string(forKey: SettingsKey.language) ?? "") ?? .system }
    static var launchPane: Pane? { d.string(forKey: SettingsKey.launchPane).flatMap(Pane.init(launchKey:)) }
    static var launchSettings: Bool { d.bool(forKey: SettingsKey.launchSettings) }
    static var unusedDays: Int { d.integer(forKey: SettingsKey.unusedDays) }
    static var largeFileMB: Int { d.integer(forKey: SettingsKey.largeFileMB) }
    static var launchUITest: String? { d.string(forKey: SettingsKey.launchUITest) }
    static var launchSkipAccess: Bool { d.bool(forKey: SettingsKey.launchSkipAccess) }

    /// Extra folders are stored as one string, one path per line (AppStorage cannot hold arrays).
    static func folders(from stored: String) -> [String] { stored.split(separator: "\n").map(String.init) }
    static func store(_ folders: [String]) -> String { folders.joined(separator: "\n") }
    static var extraFolders: [String] { folders(from: d.string(forKey: SettingsKey.extraFolders) ?? "") }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, de, en
    var id: Self { self }

    static let supported: [AppLanguage] = [.de, .en]
    static let fallback = AppLanguage.en

    /// The language code actually used: for `.system` the first preferred system language the app supports.
    var code: String {
        guard self == .system else { return rawValue }
        let preferred = Locale.preferredLanguages.compactMap { Locale(identifier: $0).language.languageCode?.identifier }
        return preferred.first { code in Self.supported.contains { $0.rawValue == code } } ?? Self.fallback.rawValue
    }

    /// Each language names itself ("Deutsch", "English"); the system entry names the language it resolves to.
    var title: String {
        let own = { (code: String) in Locale(identifier: code).localizedString(forLanguageCode: code)?.capitalized ?? code }
        return self == .system ? Loc.languageSystem.f(own(code)) : own(rawValue)
    }
}

enum AppAppearance: Int, CaseIterable, Identifiable {
    case system, light, dark
    var id: Self { self }

    var title: Loc {
        switch self {
        case .system: .appearanceSystem
        case .light: .appearanceLight
        case .dark: .appearanceDark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

enum LayoutMode: Int, CaseIterable, Identifiable {
    case list, grid
    var id: Self { self }
    var title: Loc { self == .list ? .layoutList : .layoutGrid }
    var symbol: String { self == .list ? Symbols.list : Symbols.grid }
}

enum ChartPalette: Int, CaseIterable, Identifiable {
    case colourful, accent, greys
    var id: Self { self }

    var title: Loc {
        switch self {
        case .colourful: .paletteColourful
        case .accent: .paletteAccent
        case .greys: .paletteGrey
        }
    }
}
