/// Storage categories like in System Settings › Storage. Each kind owns its folders; the most specific folder wins.
/// Folders that do not exist on a Mac simply stay empty, so the same rules work everywhere.
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
        case .apps: "square.grid.2x2"
        case .documents: "doc.text"
        case .downloads: "arrow.down.circle"
        case .media: "photo.on.rectangle"
        case .iCloud: "icloud"
        case .mail: "envelope"
        case .developer: "hammer"
        case .caches: "archivebox"
        case .appData: "shippingbox"
        case .trash: "trash"
        case .temp: "hourglass"
        case .user: "person.crop.circle"
        case .library: "gearshape"
        case .other: "folder"
        case .purgeable: "arrow.3.trianglepath"
        case .system: "internaldrive"
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
        var byPath: [String: CategoryKind] = [:]
        for kind in CategoryKind.allCases { for p in kind.paths { byPath[Paths.expand(p)] = kind } }
        var cats = CategoryKind.allCases.map { Category(kind: $0) }

        func walk(_ n: Node, _ path: String, _ inherited: CategoryKind) {
            let hit = byPath[path]
            let kind = hit ?? inherited
            if hit != nil && cats[kind.rawValue].node == nil { cats[kind.rawValue].node = n }
            var own = n.bytes
            for ch in n.children {
                walk(ch, path + "/" + ch.name, kind)
                own -= ch.bytes
            }
            cats[kind.rawValue].bytes += own
        }
        for r in root.children { walk(r, r.name, .other) }

        if let v = volume {
            let scanned = cats.reduce(0) { $0 + $1.bytes }
            cats[CategoryKind.purgeable.rawValue].bytes = v.purgeable
            // Clones count in full while scanning, so this can go below zero; then it stays empty.
            cats[CategoryKind.system.rawValue].bytes = max(0, v.used - v.purgeable - scanned)
        }
        return cats.filter { $0.bytes > 0 }.sorted { $0.bytes > $1.bytes }
    }
}
