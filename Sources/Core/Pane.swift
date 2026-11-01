/// Every page of the app; the sidebar is built from it. A new page needs a case here, its line in
/// `details` and its view in `Pane.page` (Features/Pages.swift).
enum Pane: Hashable {
    case overview, explorer, largeFiles, cleaner, duplicates, apps, temporaryFiles, copies
    case volume(String)

    static let main: [Pane] = [.overview, .explorer, .largeFiles]
    static let tidy: [Pane] = [.cleaner, .duplicates, .apps]
    /// Expert pages: the sidebar lists them only when the settings ask for it (see `SidebarList`).
    static let advanced: [Pane] = [.temporaryFiles, .copies]
    static let everyPage = main + tidy + advanced

    var supportsGrid: Bool {
        [.overview, .explorer, .largeFiles, .apps].contains(self)
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
    /// One sentence at the top of the page: what it is for and what to do there.
    var guidance: TextKey { details.guidance }
    /// More about the page, shown by its information button.
    var information: TextKey { details.information }
    var symbol: String { details.symbol }

    /// One row of the page table.
    private struct Details {
        let key: String
        let title: TextKey
        let guidance: TextKey
        let information: TextKey
        let symbol: String

        init(
            _ key: String, _ title: TextKey, _ guidance: TextKey, _ information: TextKey,
            _ symbol: String
        ) {
            self.key = key
            self.title = title
            self.guidance = guidance
            self.information = information
            self.symbol = symbol
        }
    }

    private var details: Details {
        switch self {
        case .overview:
            Details("overview", .paneOverview, .guideOverview, .infoOverview, Symbols.overview)
        case .explorer:
            Details("explorer", .paneExplorer, .guideExplorer, .infoExplorer, Symbols.explorer)
        case .largeFiles:
            Details(
                "largeFiles", .paneLargeFiles, .guideLargeFiles, .infoLargeFiles,
                Symbols.largeFiles)
        case .cleaner:
            Details("cleaner", .paneCleaner, .guideCleaner, .infoCleaner, Symbols.cleaner)
        case .duplicates:
            Details(
                "duplicates", .paneDuplicates, .guideDuplicates, .infoDuplicates,
                Symbols.duplicates)
        case .apps: Details("apps", .paneApps, .guideApps, .infoApps, Symbols.apps)
        case .temporaryFiles:
            Details(
                "temporaryFiles", .paneTemporaryFiles, .guideTemporaryFiles, .infoTemporaryFiles,
                Symbols.temporaryArea)
        case .copies: Details("copies", .paneCopies, .guideCopies, .infoCopies, Symbols.copies)
        case .volume(let path):
            Details(path, .sectionVolumes, .guideVolume, .infoVolume, Symbols.internalDrive)
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

    /// A symbol instead of the folder's one-letter name, which tells nobody what is inside.
    var symbol: String {
        switch self {
        case .temporaryFiles: Symbols.temporaryArea
        case .caches: Symbols.caches
        case .appCopies: Symbols.copies
        case .systemServices: Symbols.library
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
