import SwiftUI

/// Folders, search results and large files as a table or as tiles, depending on the toolbar switch.
/// While a scan runs, an empty result says so instead of "nothing found".
struct EntryBrowser: View {
    let entries: [Entry]
    let total: Int64
    var showLocation = false
    let emptyTitle: String
    var emptyDetail: String?
    /// Changes when the whole content is replaced (other folder, query, filter or threshold). The table is then
    /// rebuilt instead of diffed row by row; diffing a completely new result set made AppKit report reentrant
    /// NSTableView delegate calls.
    var contentKey = ""
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.layoutMode) private var layout = LayoutMode.list
    @State private var info: Entry?

    var body: some View {
        Group {
            if layout == .grid {
                ScrollView {
                    TileGrid(data: entries.sorted { $0.bytes > $1.bytes }) { e in
                        UI.tile(icon: e.path.map { .file($0) } ?? .letter("…"), title: e.name, value: Fmt.bytes(e.bytes),
                                detail: showLocation ? e.location : nil, share: Double(e.bytes) / Double(max(total, 1)))
                            .onTapGesture(count: 2) { model.activate(e) }
                            .contextMenu { EntryMenu(entry: e, info: $info) }
                    }
                    .padding(Layout.pagePadding)
                }
                .background(Backdrop())
            } else {
                EntryTable(entries: entries, total: total, showLocation: showLocation).id(contentKey)
            }
        }
        .overlay { if entries.isEmpty { UI.emptyOrScanning(emptyTitle, symbol: Symbols.search, detail: emptyDetail) } }
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
            if let node = entry.node { Button(Loc.open.s) { model.open(node) } }
            Button(Loc.showInFinder.s) { FinderService.reveal(path) }
            Button(Loc.info.s) { info = entry }
            Divider()
            Button(Loc.copyPath.s) { FinderService.copyPath(path) }
        }
    }
}
