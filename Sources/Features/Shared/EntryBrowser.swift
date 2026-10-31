import SwiftUI

/// Folders, search results and large files as a table or as tiles, depending on the toolbar switch.
/// While a scan runs, an empty result says so instead of "nothing found".
struct EntryBrowser: View {
    let entries: [Entry]
    let total: Int64
    var showsLocation = false
    let emptyTitle: String
    var emptyDetail: String?
    /// Changes when the whole content is replaced; the table is then rebuilt, not diffed (see
    /// ARCHITECTURE.md).
    var contentKey = ""
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.layoutMode) private var layout = LayoutMode.list
    @State private var informationEntry: Entry?

    private static let clicksToOpen = 2

    var body: some View {
        Group {
            if layout == .grid {
                ScrollView { tiles.padding(Space.page) }
                    .background(Backdrop())
            } else {
                EntryTable(
                    entries: entries, total: total, showsLocation: showsLocation,
                    informationEntry: $informationEntry
                )
                .id(contentKey)
            }
        }
        .overlay {
            if entries.isEmpty {
                UI.Placeholder(
                    .emptyAfterScan(title: emptyTitle, symbol: Symbols.search, detail: emptyDetail))
            }
        }
        .sheet(item: $informationEntry) { entry in InformationSheet(entry: entry) }
        .smoothChanges(of: layout)
    }

    private var tiles: some View {
        let largestFirst = entries.sorted { first, second in first.bytes > second.bytes }
        return UI.TileGrid(largestFirst) { entry in
            UI.Tile(
                icon: entry.path.map(IconKind.preview) ?? .letter("…"), title: entry.name,
                value: Format.bytes(entry.bytes),
                detail: showsLocation ? entry.location : nil,
                share: Double(entry.bytes) / Double(max(total, 1))
            )
            .onTapGesture(count: Self.clicksToOpen) { model.activate(entry) }
            .contextMenu { EntryMenu(entry: entry, informationEntry: $informationEntry) }
        }
    }
}

/// The context menu of a row or tile, the same everywhere.
struct EntryMenu: View {
    let entry: Entry
    @Binding var informationEntry: Entry?
    @Environment(AppModel.self) private var model

    var body: some View {
        if let path = entry.path {
            if let node = entry.node { Button(TextKey.open.translated) { model.open(node) } }
            Button(TextKey.showInFinder.translated) { FinderService.reveal(path) }
            Button(TextKey.info.translated) { informationEntry = entry }
            Divider()
            Button(TextKey.copyPath.translated) { FinderService.copyPath(path) }
        }
    }
}
