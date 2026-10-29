import SwiftUI

/// The one table for folders, search results and large files: same columns, menu and double-click everywhere.
/// The location column only exists where entries come from different folders. No column customisation (see
/// ARCHITECTURE.md).
struct EntryTable: View {
    let entries: [Entry]
    let total: Int64
    var showLocation = false
    @Environment(AppModel.self) private var model
    @State private var selection: Set<Entry.ID> = []
    @State private var sort = [KeyPathComparator(\Entry.bytes, order: .reverse)]
    @State private var info: Entry?

    var body: some View {
        let rows = entries.sorted(using: sort)
        Group {
            if showLocation {
                Table(rows, selection: $selection, sortOrder: $sort) {
                    nameColumn
                    TableColumn(TextKey.columnLocation.translated, value: \.location) {
                        Text($0.location).lineLimit(1).truncationMode(.middle)
                    }
                    sizeColumn
                    shareColumn
                    filesColumn
                }
            } else {
                Table(rows, selection: $selection, sortOrder: $sort) {
                    nameColumn
                    sizeColumn
                    shareColumn
                    filesColumn
                }
            }
        }
        .contextMenu(forSelectionType: Entry.ID.self) { ids in
            if let entry = rows.first(where: { ids.contains($0.id) }) {
                EntryMenu(entry: entry, info: $info)
            }
        } primaryAction: { ids in
            rows.first { ids.contains($0.id) }.map(model.activate)
        }
        .sheet(item: $info) { InfoSheet(entry: $0) }
    }

    private var nameColumn: some TableColumnContent<Entry, KeyPathComparator<Entry>> {
        TableColumn(TextKey.columnName.translated, value: \.name) { UI.FileCell($0) }
    }

    private var sizeColumn: some TableColumnContent<Entry, KeyPathComparator<Entry>> {
        TableColumn(TextKey.columnSize.translated, value: \.bytes) {
            UI.NumberCell(bytes: $0.bytes)
        }
        .width(
            min: Layout.sizeColumn.min, ideal: Layout.sizeColumn.ideal, max: Layout.sizeColumn.max)
    }

    private var shareColumn: some TableColumnContent<Entry, KeyPathComparator<Entry>> {
        TableColumn(TextKey.columnShare.translated, value: \.bytes) {
            UI.ShareCell($0.bytes, of: total)
        }
        .width(min: Layout.shareColumn.min, ideal: Layout.shareColumn.ideal)
    }

    private var filesColumn: some TableColumnContent<Entry, KeyPathComparator<Entry>> {
        TableColumn(TextKey.columnFiles.translated, value: \.items) {
            UI.NumberCell(count: $0.items)
        }
        .width(
            min: Layout.countColumn.min, ideal: Layout.countColumn.ideal,
            max: Layout.countColumn.max)
    }
}

extension Entry {
    var location: String {
        path.map { Paths.display(($0 as NSString).deletingLastPathComponent) } ?? ""
    }
}
