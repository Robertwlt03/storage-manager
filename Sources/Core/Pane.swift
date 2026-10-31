/// Every page of the app; the sidebar is built from it. A new page needs a case here, its line in
/// `details` and its view in `Pane.page` (Features/Pages.swift).
enum Pane: Hashable {
    case overview, explorer, largeFiles, cleaner, duplicates, apps, temporaryFiles, copies
    case volume(String)

    static let main: [Pane] = [.overview, .explorer, .largeFiles]
    static let tidy: [Pane] = [.cleaner, .duplicates, .apps]
    static let system: [Pane] = [.temporaryFiles, .copies]
    static let everyPage = main + tidy + system

    var supportsGrid: Bool {
        [.overview, .explorer, .largeFiles, .duplicates, .apps].contains(self)
    }
    /// Only Folders can show its contents as rings.
    var supportsRings: Bool { self == .explorer }

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
    /// What the page is for, shown by its information button.
    var information: TextKey { details.information }
    var symbol: String { details.symbol }

    /// One row of the page table.
    private struct Details {
        let key: String
        let title: TextKey
        let information: TextKey
        let symbol: String

        init(_ key: String, _ title: TextKey, _ information: TextKey, _ symbol: String) {
            self.key = key
            self.title = title
            self.information = information
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
        case .duplicates:
            Details("duplicates", .paneDuplicates, .infoDuplicates, Symbols.duplicates)
        case .apps: Details("apps", .paneApps, .infoApps, Symbols.apps)
        case .temporaryFiles:
            Details(
                "temporaryFiles", .paneTemporaryFiles, .infoTemporaryFiles, Symbols.temporaryArea)
        case .copies: Details("copies", .paneCopies, .infoCopies, Symbols.copies)
        case .volume(let path): Details(path, .sectionVolumes, .infoVolume, Symbols.internalDrive)
        }
    }
}

/// The four subfolders of the per-user temporary area.
nonisolated enum TemporaryAreaPart: String, CaseIterable, Identifiable {
    case temporaryFiles = "T"
    case caches = "C"
    case appCopies = "X"
    case systemServices = "0"
    var id: Self { self }

    var title: TextKey {
        switch self {
        case .temporaryFiles: .temporaryFolderT
        case .caches: .temporaryFolderC
        case .appCopies: .temporaryFolderX
        case .systemServices: .temporaryFolder0
        }
    }

    var detail: TextKey {
        switch self {
        case .temporaryFiles: .temporaryFolderTDetail
        case .caches: .temporaryFolderCDetail
        case .appCopies: .temporaryFolderXDetail
        case .systemServices: .temporaryFolder0Detail
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

/// Command-line switches of the binary (used by scripts/build.py and for checks).
enum LaunchCommand: String {
    case selfTest = "--selftest"
    case renderIcon = "--render-icon"
    case listPages = "--list-pages"
}
