/// Every page of the app; the sidebar is built from it. A new page needs a case here, its line in
/// `details` and its view in `Pane.page` (Features/Pages.swift).
enum Pane: Hashable {
    case overview, explorer, largeFiles, cleaner, apps, temp, copies
    case volume(String)

    static let main: [Pane] = [.overview, .explorer, .largeFiles]
    static let tidy: [Pane] = [.cleaner, .apps]
    static let system: [Pane] = [.temp, .copies]

    /// Pages whose contents can be shown as a list or as a grid.
    var supportsGrid: Bool { [.overview, .explorer, .largeFiles, .apps].contains(self) }

    init?(launchKey: String) {
        if launchKey.hasPrefix("/") {  // a volume by its mount point, e.g. `-pane /`
            self = .volume(launchKey)
            return
        }
        let everyPage = Self.main + Self.tidy + Self.system
        guard let page = everyPage.first(where: { page in page.launchKey == launchKey }) else {
            return nil
        }
        self = page
    }

    var launchKey: String { details.key }
    var title: TextKey { details.title }
    var info: TextKey { details.info }  // what the page is for, shown by its info button
    var symbol: String { details.symbol }

    private var details: (key: String, title: TextKey, info: TextKey, symbol: String) {
        switch self {
        case .overview: ("overview", .paneOverview, .infoOverview, Symbols.overview)
        case .explorer: ("explorer", .paneExplorer, .infoExplorer, Symbols.explorer)
        case .largeFiles: ("largeFiles", .paneLargeFiles, .infoLargeFiles, Symbols.largeFiles)
        case .cleaner: ("cleaner", .paneCleaner, .infoCleaner, Symbols.cleaner)
        case .apps: ("apps", .paneApps, .infoApps, Symbols.apps)
        case .temp: ("temp", .paneTemp, .infoTemp, Symbols.temporaryArea)
        case .copies: ("copies", .paneCopies, .infoCopies, Symbols.copies)
        case .volume(let path): (path, .sectionVolumes, .infoVolume, Symbols.internalDrive)
        }
    }
}

/// The four subfolders of the per-user temporary area.
enum TempPart: String, CaseIterable, Identifiable {
    case temporaryFiles = "T"
    case caches = "C"
    case appCopies = "X"
    case systemServices = "0"
    var id: Self { self }

    var title: TextKey {
        switch self {
        case .temporaryFiles: .tempFolderT
        case .caches: .tempFolderC
        case .appCopies: .tempFolderX
        case .systemServices: .tempFolder0
        }
    }

    var detail: TextKey {
        switch self {
        case .temporaryFiles: .tempFolderTDetail
        case .caches: .tempFolderCDetail
        case .appCopies: .tempFolderXDetail
        case .systemServices: .tempFolder0Detail
        }
    }
}

enum SearchScope: CaseIterable, Identifiable {
    case all, folders, files
    var id: Self { self }

    var title: TextKey {
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
