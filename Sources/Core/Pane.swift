/// Every page of the app; the sidebar is built from it. A new page needs a case here, its line in
/// `details` and its view in `Pane.page` (Features/Pages.swift).
enum Pane: Hashable {
    case overview, explorer, largeFiles, cleaner, apps, temp, copies
    case volume(String)

    static let main: [Pane] = [.overview, .explorer, .largeFiles]
    static let tidy: [Pane] = [.cleaner, .apps]
    static let system: [Pane] = [.temp, .copies]
    static let everyPage = main + tidy + system

    /// Pages whose contents can be shown as a list or as a grid.
    var supportsGrid: Bool { [.overview, .explorer, .largeFiles, .apps].contains(self) }

    init?(launchKey: String) {
        if launchKey.hasPrefix("/") {  // a volume by its mount point, e.g. `-pane /`
            self = .volume(launchKey)
            return
        }
        guard let page = Self.everyPage.first(where: { page in page.launchKey == launchKey }) else {
            return nil
        }
        self = page
    }

    var launchKey: String { details.key }
    var title: TextKey { details.title }
    var info: TextKey { details.info }  // what the page is for, shown by its info button
    var symbol: String { details.symbol }

    /// One row of the page table: launch key, title, info text and symbol.
    private struct Details {
        let key: String
        let title: TextKey
        let info: TextKey
        let symbol: String

        init(_ key: String, _ title: TextKey, _ info: TextKey, _ symbol: String) {
            self.key = key
            self.title = title
            self.info = info
            self.symbol = symbol
        }
    }

    private var details: Details {
        switch self {
        case .overview: Details("overview", .paneOverview, .infoOverview, Symbols.overview)
        case .explorer: Details("explorer", .paneExplorer, .infoExplorer, Symbols.explorer)
        case .largeFiles:
            Details("largeFiles", .paneLargeFiles, .infoLargeFiles, Symbols.largeFiles)
        case .cleaner: Details("cleaner", .paneCleaner, .infoCleaner, Symbols.cleaner)
        case .apps: Details("apps", .paneApps, .infoApps, Symbols.apps)
        case .temp: Details("temp", .paneTemp, .infoTemp, Symbols.temporaryArea)
        case .copies: Details("copies", .paneCopies, .infoCopies, Symbols.copies)
        case .volume(let path): Details(path, .sectionVolumes, .infoVolume, Symbols.internalDrive)
        }
    }
}

/// The four subfolders of the per-user temporary area.
nonisolated enum TempPart: String, CaseIterable, Identifiable {
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
    case selfTest = "--selftest"
    case renderIcon = "--render-icon"
    case listPages = "--list-pages"
}
