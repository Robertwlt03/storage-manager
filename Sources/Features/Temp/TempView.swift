import SwiftUI

/// The hidden per-user area under /private/var/folders with its four subfolders.
struct TempView: View {
    @Environment(AppModel.self) private var model

    private var tempArea: Node? {
        _ = model.revision
        return model.root.descendant(at: Paths.tempArea)
    }

    var body: some View {
        UI.Page(.temp, options: { viewCopiesButton }, content)
    }

    @ViewBuilder private var viewCopiesButton: some View {
        if !model.copyGroups.isEmpty {
            UI.ActionButton(TextKey.viewCopies.translated) { model.pane = .copies }
        }
    }

    @ViewBuilder private func content() -> some View {
        if let tempArea {
            UI.Card {
                UI.Fields([
                    UI.Field(.location, Paths.tempArea),
                    UI.Field(.total, Format.bytes(tempArea.bytes)),
                ])
            }
            UI.Card(TextKey.subfolders.translated) {
                UI.Rows(TempPart.allCases) { part in row(part, in: tempArea) }
            }
        } else {
            UI.Placeholder(.notMeasured, in: .page)
        }
    }

    private func row(_ part: TempPart, in tempArea: Node) -> some View {
        let folder = tempArea.child(named: part.rawValue)
        return UI.NavRow(
            part.title.translated, icon: .letter(part.rawValue),
            detail: part.detail.translated,
            value: folder.map { folder in Format.bytes(folder.bytes) } ?? "–",
            action: folder.map { folder in { model.open(folder) } })
    }
}
