/// Every page of the app. The sidebar is built from this enum, so a new page cannot be forgotten there.
enum Pane: Hashable {
    case overview, statistics, explorer, largeFiles, cleaner, apps, temp, copies
    case volume(String)

    static let main: [Pane] = [.overview, .statistics, .explorer, .largeFiles]
    static let tidy: [Pane] = [.cleaner, .apps]
    static let system: [Pane] = [.temp, .copies]

    /// Pages whose contents can be shown as a list or as a grid.
    var supportsGrid: Bool { [.overview, .explorer, .largeFiles, .apps].contains(self) }

    init?(launchKey: String) {
        guard let p = (Self.main + Self.tidy + Self.system).first(where: { $0.launchKey == launchKey }) else { return nil }
        self = p
    }

    var launchKey: String {
        switch self {
        case .overview: "overview"
        case .statistics: "statistics"
        case .cleaner: "cleaner"
        case .apps: "apps"
        case .explorer: "explorer"
        case .largeFiles: "largeFiles"
        case .temp: "temp"
        case .copies: "copies"
        case .volume(let path): path
        }
    }

    var title: Loc {
        switch self {
        case .overview: .paneOverview
        case .statistics: .paneStatistics
        case .cleaner: .paneCleaner
        case .apps: .paneApps
        case .explorer: .paneExplorer
        case .largeFiles: .paneLargeFiles
        case .temp: .paneTemp
        case .copies: .paneCopies
        case .volume: .sectionVolumes
        }
    }

    var symbol: String {
        switch self {
        case .overview: Symbols.overview
        case .statistics: Symbols.statistics
        case .cleaner: Symbols.cleaner
        case .apps: Symbols.apps
        case .explorer: Symbols.explorer
        case .largeFiles: Symbols.largeFiles
        case .temp: Symbols.temp
        case .copies: Symbols.copies
        case .volume: Symbols.internalDrive
        }
    }
}

/// The four subfolders of the per-user temporary area.
enum TempPart: String, CaseIterable, Identifiable {
    case t = "T", c = "C", x = "X", zero = "0"
    var id: Self { self }

    var title: Loc {
        switch self {
        case .t: .tempT
        case .c: .tempC
        case .x: .tempX
        case .zero: .temp0
        }
    }

    var detail: Loc {
        switch self {
        case .t: .tempTDetail
        case .c: .tempCDetail
        case .x: .tempXDetail
        case .zero: .temp0Detail
        }
    }
}

enum SearchScope: CaseIterable, Identifiable {
    case all, folders, files
    var id: Self { self }

    var title: Loc {
        switch self {
        case .all: .scopeAll
        case .folders: .scopeFolders
        case .files: .scopeFiles
        }
    }
}

/// Command-line switches of the binary (used by build.sh and for checks).
enum LaunchCommand: String {
    case checkContrast = "--check-contrast"
    case checkStrings = "--check-strings"
    case selfTest = "--selftest"
    case renderIcon = "--render-icon"
}
