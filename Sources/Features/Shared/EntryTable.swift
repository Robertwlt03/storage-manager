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
    @State private var sortOrder = [KeyPathComparator(\Entry.bytes, order: .reverse)]
    @State private var infoEntry: Entry?

    var body: some View {
        let rows = entries.sorted(using: sortOrder)
        Group {
            if showLocation {
                Table(rows, selection: $selection, sortOrder: $sortOrder) {
                    nameColumn
                    locationColumn
                    sizeColumn
                    shareColumn
                    filesColumn
                }
            } else {
                Table(rows, selection: $selection, sortOrder: $sortOrder) {
                    nameColumn
                    sizeColumn
                    shareColumn
                    filesColumn
                }
            }
        }
        .contextMenu(forSelectionType: Entry.ID.self) { selectedIDs in
            if let entry = firstEntry(in: rows, with: selectedIDs) {
                EntryMenu(entry: entry, infoEntry: $infoEntry)
            }
        } primaryAction: { selectedIDs in
            firstEntry(in: rows, with: selectedIDs).map(model.activate)
        }
        .sheet(item: $infoEntry) { entry in InfoSheet(entry: entry) }
    }

    private func firstEntry(in rows: [Entry], with selectedIDs: Set<Entry.ID>) -> Entry? {
        rows.first { entry in selectedIDs.contains(entry.id) }
    }

    private var nameColumn: some TableColumnContent<Entry, KeyPathComparator<Entry>> {
        TableColumn(TextKey.columnName.translated, value: \.name) { entry in UI.FileCell(entry) }
    }

    private var locationColumn: some TableColumnContent<Entry, KeyPathComparator<Entry>> {
        TableColumn(TextKey.columnLocation.translated, value: \.location) { entry in
            Text(entry.location).lineLimit(1).truncationMode(.middle)
        }
    }

    private var sizeColumn: some TableColumnContent<Entry, KeyPathComparator<Entry>> {
        TableColumn(TextKey.columnSize.translated, value: \.bytes) { entry in
            UI.NumberCell(bytes: entry.bytes)
        }
        .width(
            min: Layout.sizeColumn.min, ideal: Layout.sizeColumn.ideal, max: Layout.sizeColumn.max)
    }

    private var shareColumn: some TableColumnContent<Entry, KeyPathComparator<Entry>> {
        TableColumn(TextKey.columnShare.translated, value: \.bytes) { entry in
            UI.ShareCell(entry.bytes, of: total)
        }
        .width(min: Layout.shareColumn.min, ideal: Layout.shareColumn.ideal)
    }

    private var filesColumn: some TableColumnContent<Entry, KeyPathComparator<Entry>> {
        TableColumn(TextKey.columnFiles.translated, value: \.items) { entry in
            UI.NumberCell(count: entry.items)
        }
        .width(
            min: Layout.countColumn.min, ideal: Layout.countColumn.ideal,
            max: Layout.countColumn.max)
    }
}

extension Entry {
    /// The folder the entry lies in, as shown to the user.
    var location: String {
        guard let path else { return "" }
        return Paths.display((path as NSString).deletingLastPathComponent)
    }
}
