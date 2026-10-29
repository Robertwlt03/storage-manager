import SwiftUI

/// The hidden per-user area under /private/var/folders with its four subfolders.
struct TempView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let _ = model.revision
        let area = model.root.descendant(at: Paths.tempArea)
        UI.Page(.temp, options: {
            if !model.copyGroups.isEmpty { UI.ActionButton(Loc.viewCopies.s) { model.pane = .copies } }
        }) {
            if let area {
                UI.Card {
                    UI.Fields([UI.Field(.location, Paths.tempArea), UI.Field(.total, Fmt.bytes(area.bytes))])
                }
                UI.Card(Loc.subfolders.s) {
                    UI.Rows(TempPart.allCases) { part in
                        let node = area.child(named: part.rawValue)
                        UI.NavRow(part.title.s, icon: .letter(part.rawValue), detail: part.detail.s,
                                  value: node.map { Fmt.bytes($0.bytes) } ?? "–", action: node.map { n in { model.open(n) } })
                    }
                }
            } else {
                UI.Placeholder(.notMeasured, in: .page)
            }
        }
    }
}
