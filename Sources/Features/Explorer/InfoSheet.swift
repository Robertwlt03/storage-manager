import SwiftUI

/// "Get Info" for a folder or file: basics right away, folder contents analyzed in the background.
struct InfoSheet: View {
    let entry: Entry
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    @State private var profile: FolderProfile?

    private var path: String { entry.path ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView { cards.padding(Space.page) }
                .background(Backdrop())
            buttons.padding(Space.card)
        }
        .frame(width: Layout.sheetWidth, height: Layout.sheetHeight)
        .task {
            // The demo's paths are made up, so nothing is analyzed on the disk.
            guard entry.isFolder, !model.isDemo else { return }
            let path = path
            profile = await Task.detached(priority: .utility) { ProfileService.profile(path) }.value
        }
    }

    private var cards: some View {
        VStack(alignment: .leading, spacing: Space.section) {
            UI.Card {
                UI.TitleRow(entry.name, subtitle: Paths.displayName(path), icon: .file(path))
                    .padding(.vertical, Space.row)
                Divider()
                UI.Fields(basicFields)
            }
            if entry.isFolder {
                contentsCard
                if let profile, let largestTypeBytes = profile.types.first?.bytes {
                    fileTypesCard(profile, largestTypeBytes: largestTypeBytes)
                }
            }
        }
    }

    private var buttons: some View {
        HStack {
            UI.ActionButton(TextKey.showInFinder.translated) { FinderService.reveal(path) }
            Spacer()
            UI.ActionButton(TextKey.done.translated, .primary) { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
    }

    private var basicFields: [UI.Field?] {
        let resources = try? URL(fileURLWithPath: path)
            .resourceValues(forKeys: [
                .contentModificationDateKey, .creationDateKey, .localizedTypeDescriptionKey,
            ])
        let modified = resources?.contentModificationDate
        let created = resources?.creationDate
        return [
            UI.Field(.allocated, Format.bytes(entry.bytes)),
            UI.Field(.kind, resources?.localizedTypeDescription ?? "–"),
            modified.map { date in UI.Field(.modified, Format.dateTime(date)) },
            created.map { date in UI.Field(.created, Format.dateTime(date)) },
        ]
    }

    private var contentsCard: some View {
        UI.Card(TextKey.contents.translated) {
            if let profile {
                UI.Fields([
                    UI.Field(.files, Format.count(profile.files)),
                    UI.Field(.folders, Format.count(profile.folders)),
                    UI.Field(.packages, Format.count(profile.packages)),
                    modifiedBetweenField(profile),
                ])
            } else {
                UI.Note(TextKey.analyzing.translated, .working).padding(.vertical, Space.row)
            }
        }
    }

    private func modifiedBetweenField(_ profile: FolderProfile) -> UI.Field? {
        guard let oldest = profile.oldest, let newest = profile.newest else { return nil }
        let dateRange = TextKey.dateRange.translated(
            with: Format.numericDay(oldest), Format.numericDay(newest))
        return UI.Field(.modifiedBetween, dateRange)
    }

    private func fileTypesCard(_ profile: FolderProfile, largestTypeBytes: Int64) -> some View {
        let fileTypes = profile.types.map { fileType in
            FileTypeRow(
                fileExtension: fileType.fileExtension, bytes: fileType.bytes, count: fileType.count)
        }
        return UI.Card(TextKey.typesBySize.translated) {
            UI.Rows(fileTypes) { fileType in
                HStack(spacing: Space.item) {
                    Text(fileType.fileExtension).frame(maxWidth: .infinity, alignment: .leading)
                    UI.ShareCell(fileType.bytes, of: largestTypeBytes)
                    UI.NumberCell(bytes: fileType.bytes).frame(width: Layout.sizeColumn.ideal)
                    Text(TextKey.fileCount.translated(with: Format.count(fileType.count)))
                        .textRole(.value)
                }
            }
        }
    }

    private struct FileTypeRow: Identifiable {
        let fileExtension: String
        let bytes: Int64
        let count: Int
        var id: String { fileExtension }
    }
}
