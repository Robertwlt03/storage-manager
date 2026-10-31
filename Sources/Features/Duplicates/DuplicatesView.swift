import SwiftUI

/// Large files that exist more than once with the same content, each group one after another.
/// Nothing is removed here; Show in Finder leads to them.
struct DuplicatesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let groups = model.duplicateGroups {
                list(groups)
            } else {
                UI.Placeholder(
                    .loading(
                        title: .searchingDuplicates, detail: .searchingDuplicatesDetail,
                        symbol: Symbols.duplicates),
                    in: .page)
            }
        }
        .navigationTitle(TextKey.paneDuplicates.translated)
        .safeAreaInset(edge: .top, spacing: 0) { UI.PageHeader(Pane.duplicates.information) {} }
        // Waits for a running scan; the search starts once the tree is complete.
        .task(id: model.isScanning ? nil : model.revision) { await model.findDuplicates() }
    }

    private func list(_ groups: [[Entry]]) -> some View {
        let files = groups.flatMap(\.self)
        let spareBytes = groups.reduce(0) { total, group in
            total + group[0].bytes * Int64(group.count - 1)
        }
        return EntryBrowser(
            entries: files, total: files.reduce(0) { total, file in total + file.bytes },
            showsLocation: true, emptyTitle: TextKey.noDuplicates.translated,
            contentKey: "\(model.revision)"
        )
        .navigationSubtitle(
            TextKey.duplicatesTotal.translated(
                with: Format.count(files.count), Format.bytes(spareBytes)))
    }
}
