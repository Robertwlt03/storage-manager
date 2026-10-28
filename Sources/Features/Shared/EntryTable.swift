import SwiftUI

/// The one table for folders, search results and large files: same columns, menu and double-click everywhere.
struct EntryTable: View {
    private enum Column {
        static let name = "name", location = "location", size = "size", share = "share", files = "files"
    }

    let entries: [Entry]
    let total: Int64
    @Environment(AppModel.self) private var model
    @State private var selection: Set<Entry.ID> = []
    @State private var sort = [KeyPathComparator(\Entry.bytes, order: .reverse)]
    @State private var columns: TableColumnCustomization<Entry>
    @State private var info: Entry?

    init(entries: [Entry], total: Int64, showLocation: Bool = false) {
        self.entries = entries
        self.total = total
        var c = TableColumnCustomization<Entry>()
        c[visibility: Column.location] = showLocation ? .visible : .hidden
        _columns = State(initialValue: c)
    }

    var body: some View {
        let rows = entries.sorted(using: sort)
        Table(rows, selection: $selection, sortOrder: $sort, columnCustomization: $columns) {
            TableColumn(Loc.columnName.s, value: \.name) { UI.fileCell($0) }
                .customizationID(Column.name)
            TableColumn(Loc.columnLocation.s, value: \.location) { Text($0.location).lineLimit(1).truncationMode(.middle) }
                .customizationID(Column.location)
            TableColumn(Loc.columnSize.s, value: \.bytes) { UI.sizeCell($0.bytes) }
                .width(min: Layout.sizeColumn.min, ideal: Layout.sizeColumn.ideal, max: Layout.sizeColumn.max)
                .customizationID(Column.size)
            TableColumn(Loc.columnShare.s, value: \.bytes) { UI.shareCell($0.bytes, of: total) }
                .width(min: Layout.shareColumn.min, ideal: Layout.shareColumn.ideal)
                .customizationID(Column.share)
            TableColumn(Loc.columnFiles.s, value: \.items) { UI.countCell($0.items) }
                .width(min: Layout.countColumn.min, ideal: Layout.countColumn.ideal, max: Layout.countColumn.max)
                .customizationID(Column.files)
        }
        .contextMenu(forSelectionType: Entry.ID.self) { ids in
            menu(for: rows.first { ids.contains($0.id) })
        } primaryAction: { ids in
            rows.first { ids.contains($0.id) }.map(activate)
        }
        .sheet(item: $info) { InfoSheet(entry: $0) }
    }

    @ViewBuilder private func menu(for entry: Entry?) -> some View {
        if let entry, let path = entry.path {
            if let node = entry.node { Button(Loc.open.s) { model.open(node) } }
            Button(Loc.showInFinder.s) { FinderService.reveal(path) }
            Button(Loc.info.s) { info = entry }
            Divider()
            Button(Loc.copyPath.s) { FinderService.copyPath(path) }
        }
    }

    /// Double-click: folders open in the explorer, files show in Finder.
    private func activate(_ entry: Entry) {
        if let node = entry.node { model.open(node) } else if let path = entry.path { FinderService.reveal(path) }
    }
}

extension Entry {
    var location: String { path.map { Paths.display(($0 as NSString).deletingLastPathComponent) } ?? "" }
}
