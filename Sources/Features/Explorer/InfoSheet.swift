import SwiftUI

/// "Get Info" for a folder or file: basics right away, folder contents analysed in the background.
struct InfoSheet: View {
    let entry: Entry
    @Environment(\.dismiss) private var dismiss
    @State private var profile: FolderProfile?

    var body: some View {
        let path = entry.path ?? ""
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    UI.Card {
                        UI.TitleRow(entry.name, subtitle: Paths.display(path), icon: .file(path))
                            .padding(.vertical, Space.row)
                        Divider()
                        UI.Fields(basics(path))
                    }
                    if entry.isFolder { contents }
                }
                .padding(Space.page)
            }
            .background(Backdrop())
            HStack {
                UI.ActionButton(TextKey.showInFinder.translated) { FinderService.reveal(path) }
                Spacer()
                UI.ActionButton(TextKey.done.translated, .primary) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(Space.card)
        }
        .frame(width: Layout.sheetWidth, height: Layout.sheetHeight)
        .task {
            guard entry.isFolder else { return }
            profile = await Task.detached(priority: .utility) { ProfileService.profile(path) }.value
        }
    }

    private func basics(_ path: String) -> [UI.Field?] {
        let v = try? URL(fileURLWithPath: path)
            .resourceValues(forKeys: [
                .contentModificationDateKey, .creationDateKey,
                .localizedTypeDescriptionKey,
            ])
        return [
            UI.Field(.allocated, Format.bytes(entry.bytes)),
            UI.Field(.kind, v?.localizedTypeDescription ?? "–"),
            v?.contentModificationDate.map { UI.Field(.modified, Format.dateTime($0)) },
            v?.creationDate.map { UI.Field(.created, Format.dateTime($0)) },
        ]
    }

    @ViewBuilder private var contents: some View {
        UI.Card(TextKey.contents.translated) {
            if let p = profile {
                UI.Fields([
                    UI.Field(.files, Format.count(p.files)),
                    UI.Field(.folders, Format.count(p.folders)),
                    UI.Field(.packages, Format.count(p.packages)),
                    p.oldest.flatMap { o in
                        p.newest.map { n in
                            UI.Field(
                                .modifiedBetween,
                                TextKey.dateRange.translated(
                                    with: Format.dayShort(o), Format.dayShort(n)))
                        }
                    },
                ])
            } else {
                UI.Note(TextKey.analyzing.translated, .working).padding(.vertical, Space.row)
            }
        }
        if let p = profile, let top = p.types.first?.bytes {
            UI.Card(TextKey.typesBySize.translated) {
                UI.Rows(p.types.map { TypeRow(ext: $0.ext, bytes: $0.bytes, count: $0.count) }) {
                    t in
                    HStack(spacing: Space.item) {
                        Text(t.ext).frame(maxWidth: .infinity, alignment: .leading)
                        UI.ShareCell(t.bytes, of: top)
                        UI.NumberCell(bytes: t.bytes).frame(width: Layout.sizeColumn.ideal)
                        Text(TextKey.fileCount.translated(with: Format.count(t.count)))
                            .textRole(.value)
                    }
                }
            }
        }
    }

    private struct TypeRow: Identifiable {
        let ext: String
        let bytes: Int64
        let count: Int
        var id: String { ext }
    }
}
