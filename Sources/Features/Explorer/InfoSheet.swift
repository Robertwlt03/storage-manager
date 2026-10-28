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
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    UI.card {
                        UI.header(entry.name, subtitle: Paths.display(path), icon: .file(path), size: Layout.sheetIcon)
                            .padding(.vertical, Layout.rowPadding)
                        Divider()
                        UI.fields(basics(path))
                    }
                    if entry.isFolder { contents }
                }
                .padding(Layout.pagePadding)
            }
            .background(Backdrop())
            HStack {
                UI.button(Loc.showInFinder.s) { FinderService.reveal(path) }
                Spacer()
                UI.button(Loc.done.s, prominent: true) { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(Layout.cardPadding)
        }
        .frame(width: Layout.sheetWidth, height: Layout.sheetHeight)
        .task {
            guard entry.isFolder else { return }
            profile = await Task.detached(priority: .utility) { ProfileService.profile(path) }.value
        }
    }

    private func basics(_ path: String) -> [FieldItem?] {
        let v = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey,
                                                                       .localizedTypeDescriptionKey])
        return [FieldItem(.allocated, Fmt.bytes(entry.bytes)),
                FieldItem(.kind, v?.localizedTypeDescription ?? "–"),
                v?.contentModificationDate.map { FieldItem(.modified, Fmt.dateTime($0)) },
                v?.creationDate.map { FieldItem(.created, Fmt.dateTime($0)) }]
    }

    @ViewBuilder private var contents: some View {
        UI.card(Loc.contents.s) {
            if let p = profile {
                UI.fields([FieldItem(.files, Fmt.count(p.files)),
                           FieldItem(.folders, Fmt.count(p.folders)),
                           FieldItem(.packages, Fmt.count(p.packages)),
                           p.oldest.flatMap { o in p.newest.map { n in
                               FieldItem(.modifiedBetween, Loc.dateRange.f(Fmt.dayShort(o), Fmt.dayShort(n)))
                           } }])
            } else {
                UI.progress(Loc.analyzing.s).padding(.vertical, Layout.rowPadding)
            }
        }
        if let p = profile, let top = p.types.first?.bytes {
            UI.card(Loc.typesBySize.s) {
                UI.rows(p.types.map { TypeRow(ext: $0.ext, bytes: $0.bytes, count: $0.count) }) { t in
                    HStack(spacing: Layout.rowSpacing) {
                        Text(t.ext).frame(maxWidth: .infinity, alignment: .leading)
                        UI.shareCell(t.bytes, of: top)
                        UI.sizeCell(t.bytes).frame(width: Layout.sizeColumn.ideal)
                        Text(Loc.fileCount.f(Fmt.count(t.count))).foregroundStyle(.muted).monospacedDigit()
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
