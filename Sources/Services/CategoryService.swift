/// Storage categories like in System Settings › Storage. Each kind owns its folders; the most
/// specific folder wins. Folders that do not exist on a Mac simply stay empty, so the same rules
/// work everywhere.
enum CategoryKind: Int, CaseIterable {
    case apps, documents, downloads, media, iCloud, mail, developer, caches, appData, trash, temp,
        user, library
    case other, purgeable, system

    /// Kinds that come from what macOS reports, not from the scan.
    static let estimated: Set<CategoryKind> = [.purgeable, .system]

    var title: TextKey {
        switch self {
        case .apps: .categoryApps
        case .documents: .categoryDocuments
        case .downloads: .categoryDownloads
        case .media: .categoryMedia
        case .iCloud: .categoryICloud
        case .mail: .categoryMail
        case .developer: .categoryDeveloper
        case .caches: .categoryCaches
        case .appData: .categoryAppData
        case .trash: .categoryTrash
        case .temp: .categoryTemp
        case .user: .categoryUser
        case .library: .categoryLibrary
        case .other: .categoryOther
        case .purgeable: .categoryPurgeable
        case .system: .categorySystem
        }
    }

    var symbol: String {
        switch self {
        case .apps: Symbols.appCollection
        case .documents: Symbols.documents
        case .downloads: Symbols.downloads
        case .media: Symbols.media
        case .iCloud: Symbols.iCloud
        case .mail: Symbols.mail
        case .developer: Symbols.developer
        case .caches: Symbols.caches
        case .appData: Symbols.appData
        case .trash: Symbols.trash
        case .temp: Symbols.temporaryArea
        case .user: Symbols.user
        case .library: Symbols.library
        case .other: Symbols.otherFiles
        case .purgeable: Symbols.purgeable
        case .system: Symbols.internalDrive
        }
    }

    /// `~` stands for the home folder.
    var paths: [String] {
        switch self {
        case .apps: [Paths.applications, "~/Applications"]
        case .documents: ["~/Documents", "~/Desktop"]
        case .downloads: ["~/Downloads"]
        case .media: ["~/Pictures", "~/Music", "~/Movies"]
        case .iCloud: ["~/Library/Mobile Documents"]
        case .mail: ["~/Library/Mail", "~/Library/Messages"]
        case .developer:
            [
                "~/Library/Developer", "~/.npm", "~/.cache", "~/.docker", "~/.gradle", "~/.m2",
                "~/.cargo",
                "~/.rustup", "~/go", "~/.pub-cache", "~/.composer", "~/.local",
                "~/Library/Containers/com.docker.docker", Paths.opt, Paths.usrLocal,
            ]
        case .caches: ["~/Library/Caches"]
        case .appData:
            ["~/Library/Application Support", "~/Library/Containers", "~/Library/Group Containers"]
        case .trash: ["~/.Trash"]
        case .temp: [Paths.tempArea]
        case .user: [Paths.home]
        case .library: [Paths.library]
        case .other, .purgeable, .system: []
        }
    }
}

enum CategoryService {
    /// Sums the tree into categories. With a volume it adds what macOS can purge and the remainder
    /// ("System & Other"); without one (while scanning) the remainder would be misleading.
    static func compute(root: Node, volume: VolumeInfo?) -> [Category] {
        let kindByPath = kindsByExpandedPath()
        var categories = CategoryKind.allCases.map { kind in Category(kind: kind) }

        func addBytes(of node: Node, at path: String, inheritedKind: CategoryKind) {
            let matchedKind = kindByPath[path]
            let kind = matchedKind ?? inheritedKind
            if matchedKind != nil && categories[kind.rawValue].node == nil {
                categories[kind.rawValue].node = node
            }
            var ownBytes = node.bytes
            for child in node.children {
                addBytes(of: child, at: path + "/" + child.name, inheritedKind: kind)
                ownBytes -= child.bytes
            }
            categories[kind.rawValue].bytes += ownBytes
        }
        for scanRoot in root.children {
            addBytes(of: scanRoot, at: scanRoot.name, inheritedKind: .other)
        }

        if let volume { addEstimatedKinds(from: volume, to: &categories) }
        return categories.filter { category in category.bytes > 0 }
            .sorted { left, right in left.bytes > right.bytes }
    }

    private static func kindsByExpandedPath() -> [String: CategoryKind] {
        var kindByPath: [String: CategoryKind] = [:]
        for kind in CategoryKind.allCases {
            for path in kind.paths { kindByPath[Paths.expand(path)] = kind }
        }
        return kindByPath
    }

    private static func addEstimatedKinds(from volume: VolumeInfo, to categories: inout [Category])
    {
        let scannedBytes = categories.reduce(0) { total, category in total + category.bytes }
        categories[CategoryKind.purgeable.rawValue].bytes = volume.purgeableBytes
        // Clones count in full while scanning, so this can go below zero; then it stays empty.
        categories[CategoryKind.system.rawValue].bytes = max(
            0, volume.usedBytes - volume.purgeableBytes - scannedBytes)
    }
}
