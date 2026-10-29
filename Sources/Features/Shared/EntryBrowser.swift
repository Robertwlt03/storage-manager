import SwiftUI

/// Folders, search results and large files as a table or as tiles, depending on the toolbar switch.
/// While a scan runs, an empty result says so instead of "nothing found".
struct EntryBrowser: View {
    let entries: [Entry]
    let total: Int64
    var showLocation = false
    let emptyTitle: String
    var emptyDetail: String?
    /// Changes when the whole content is replaced; the table is then rebuilt, not diffed (see ARCHITECTURE.md).
    var contentKey = ""
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.layoutMode) private var layout = LayoutMode.list
    @State private var info: Entry?

    var body: some View {
        Group {
            if layout == .grid {
                ScrollView {
                    UI.TileGrid(entries.sorted { $0.bytes > $1.bytes }) { e in
                        UI.Tile(
                            icon: e.path.map { .preview($0) } ?? .letter("…"), title: e.name,
                            value: Format.bytes(e.bytes),
                            detail: showLocation ? e.location : nil,
                            share: Double(e.bytes) / Double(max(total, 1))
                        )
                        .onTapGesture(count: 2) { model.activate(e) }
                        .contextMenu { EntryMenu(entry: e, info: $info) }
                    }
                    .padding(Space.page)
                }
                .background(Backdrop())
            } else {
                EntryTable(entries: entries, total: total, showLocation: showLocation)
                    .id(contentKey)
            }
        }
        .overlay {
            if entries.isEmpty {
                UI.Placeholder(
                    .emptyAfterScan(title: emptyTitle, symbol: Symbols.search, detail: emptyDetail))
            }
        }
        .sheet(item: $info) { InfoSheet(entry: $0) }
        .smoothChanges(of: layout)
    }
}

/// The context menu of a row or tile, the same everywhere.
struct EntryMenu: View {
    let entry: Entry
    @Binding var info: Entry?
    @Environment(AppModel.self) private var model

    var body: some View {
        if let path = entry.path {
            if let node = entry.node { Button(TextKey.open.translated) { model.open(node) } }
            Button(TextKey.showInFinder.translated) { FinderService.reveal(path) }
            Button(TextKey.info.translated) { info = entry }
            Divider()
            Button(TextKey.copyPath.translated) { FinderService.copyPath(path) }
        }
    }
}
