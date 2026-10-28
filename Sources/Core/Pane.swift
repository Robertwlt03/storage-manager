/// Every page of the app. The sidebar is built from this enum, so a new page cannot be forgotten there.
enum Pane: Hashable {
    case overview, explorer, largeFiles, temp, copies
    case volume(String)

    static let main: [Pane] = [.overview, .explorer, .largeFiles]
    static let system: [Pane] = [.temp, .copies]

    init?(launchKey: String) {
        guard let p = (Self.main + Self.system).first(where: { $0.launchKey == launchKey }) else { return nil }
        self = p
    }

    var launchKey: String {
        switch self {
        case .overview: "overview"
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
