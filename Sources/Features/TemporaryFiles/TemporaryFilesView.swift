import SwiftUI

/// The hidden per-user area under /private/var/folders with its four subfolders.
struct TemporaryFilesView: View {
    @Environment(AppModel.self) private var model

    private var temporaryArea: Node? {
        _ = model.revision
        return model.root.descendant(at: Paths.temporaryArea)
    }

    var body: some View {
        UI.Page(.temporaryFiles, options: { viewCopiesButton }, content)
    }

    @ViewBuilder private var viewCopiesButton: some View {
        if !model.copyGroups.isEmpty {
            UI.ActionButton(TextKey.viewCopies.translated) { model.pane = .copies }
        }
    }

    @ViewBuilder private func content() -> some View {
        if let temporaryArea {
            UI.Card {
                UI.Fields([
                    UI.Field(.location, model.shownTemporaryArea),
                    UI.Field(.total, Format.bytes(temporaryArea.bytes)),
                ])
            }
            UI.Card(TextKey.subfolders.translated) {
                UI.Rows(TemporaryAreaPart.allCases) { part in row(part, in: temporaryArea) }
            }
        } else {
            UI.Placeholder(.notMeasured, in: .page)
        }
    }

    private func row(_ part: TemporaryAreaPart, in temporaryArea: Node) -> some View {
        let folder = temporaryArea.child(named: part.rawValue)
        return UI.NavigationRow(
            part.title.translated, icon: .letter(part.rawValue),
            detail: part.detail.translated,
            value: folder.map { folder in Format.bytes(folder.bytes) } ?? "–",
            action: folder.map { folder in { model.open(folder) } })
    }
}
