import SwiftUI

/// Large files that exist more than once with the same content, each group as a card of its own.
/// Nothing is removed here; Show in Finder leads to them.
struct DuplicatesView: View {
    @Environment(AppModel.self) private var model
    @State private var informationEntry: Entry?

    var body: some View {
        UI.Page(.duplicates) {
            if let groups = model.duplicateGroups {
                cards(groups)
            } else {
                UI.Placeholder(
                    .loading(
                        title: .searchingDuplicates, detail: .searchingDuplicatesDetail,
                        symbol: Symbols.duplicates),
                    in: .page)
            }
        }
        .navigationSubtitle(subtitle)
        .sheet(item: $informationEntry) { entry in InformationSheet(entry: entry) }
        // Waits for a running scan; the search starts once the tree is complete.
        .task(id: model.isScanning ? nil : model.revision) { await model.findDuplicates() }
    }

    private var subtitle: String {
        guard let groups = model.duplicateGroups else { return "" }
        let spareBytes = groups.reduce(0) { total, files in total + Self.spareBytes(files) }
        return TextKey.duplicatesTotal.translated(
            with: Format.count(groups.reduce(0) { total, files in total + files.count }),
            Format.bytes(spareBytes))
    }

    @ViewBuilder private func cards(_ groups: [[Entry]]) -> some View {
        if groups.isEmpty {
            UI.Placeholder(
                .emptyAfterScan(
                    title: TextKey.noDuplicates.translated, symbol: Symbols.success,
                    detail: TextKey.noDuplicatesDetail.translated),
                in: .page)
        }
        // The most space to win first; lazy, so hundreds of groups only build the cards in view.
        let mostSpareFirst = groups.sorted { first, second in
            Self.spareBytes(first) > Self.spareBytes(second)
        }
        LazyVStack(alignment: .leading, spacing: Space.section) {
            ForEach(mostSpareFirst, id: \.[0].id) { files in card(files) }
        }
    }

    private func card(_ files: [Entry]) -> some View {
        UI.Card(
            TextKey.duplicateGroupTitle.translated(
                with: Format.count(files.count), Format.bytes(Self.spareBytes(files)))
        ) {
            UI.Rows(files) { file in row(file) }
        }
    }

    /// What all copies but one take up.
    private static func spareBytes(_ files: [Entry]) -> Int64 {
        files[0].bytes * Int64(files.count - 1)
    }

    private func row(_ file: Entry) -> some View {
        HStack(spacing: Space.item) {
            UI.Icon(file.path.map(IconKind.preview) ?? .symbol(Symbols.files))
            VStack(alignment: .leading, spacing: Space.hairline) {
                Text(file.name).lineLimit(1).truncationMode(.middle)
                Text(file.location).textRole(.hint).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: Space.item)
            if file.path != nil { trashButton(file) }
        }
        .contentShape(Rectangle())
        .contextMenu { EntryMenu(entry: file, informationEntry: $informationEntry) }
    }

    /// Every copy can go; the group leaves the page once a single file is left.
    private func trashButton(_ file: Entry) -> some View {
        UI.ActionButton(TextKey.moveToTrash.translated, .inline, role: .destructive) {
            model.fileToTrash = file
        }
    }
}
