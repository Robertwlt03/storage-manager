/// Every page of the app; the sidebar is built from it. A new page needs a case here, its line in `details` and
/// its view in `Pane.page` (Features/Pages.swift).
enum Pane: Hashable {
    case overview, explorer, largeFiles, cleaner, apps, temp, copies
    case volume(String)

    static let main: [Pane] = [.overview, .explorer, .largeFiles]
    static let tidy: [Pane] = [.cleaner, .apps]
    static let system: [Pane] = [.temp, .copies]

    /// Pages built from a table rather than a scrolling page (they need the scan banner above them).
    var showsTable: Bool { [.explorer, .largeFiles].contains(self) }

    /// Pages whose contents can be shown as a list or as a grid.
    var supportsGrid: Bool { [.overview, .explorer, .largeFiles, .apps].contains(self) }

    init?(launchKey: String) {
        if launchKey.hasPrefix("/") {  // a volume by its mount point, e.g. `-pane /`
            self = .volume(launchKey)
            return
        }
        guard let p = (Self.main + Self.tidy + Self.system).first(where: { $0.launchKey == launchKey }) else { return nil }
        self = p
    }

    var launchKey: String { details.key }
    var title: Loc { details.title }
    var info: Loc { details.info }  // what the page is for, shown by its info button
    var symbol: String { details.symbol }

    private var details: (key: String, title: Loc, info: Loc, symbol: String) {
        switch self {
        case .overview: ("overview", .paneOverview, .infoOverview, Symbols.overview)
        case .explorer: ("explorer", .paneExplorer, .infoExplorer, Symbols.explorer)
        case .largeFiles: ("largeFiles", .paneLargeFiles, .infoLargeFiles, Symbols.largeFiles)
        case .cleaner: ("cleaner", .paneCleaner, .infoCleaner, Symbols.cleaner)
        case .apps: ("apps", .paneApps, .infoApps, Symbols.apps)
        case .temp: ("temp", .paneTemp, .infoTemp, Symbols.temp)
        case .copies: ("copies", .paneCopies, .infoCopies, Symbols.copies)
        case .volume(let path): (path, .sectionVolumes, .infoVolume, Symbols.internalDrive)
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
