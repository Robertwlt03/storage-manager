import SwiftUI

/// The hidden per-user area under /private/var/folders with its four subfolders.
struct TempView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let _ = model.revision
        let area = model.root.descendant(at: Paths.tempArea)
        UI.page(.temp, options: {
            if !model.copyGroups.isEmpty { UI.button(Loc.viewCopies.s) { model.pane = .copies } }
        }) {
            if let area {
                UI.card {
                    UI.fields([FieldItem(.location, Paths.tempArea), FieldItem(.total, Fmt.bytes(area.bytes))])
                }
                UI.card(Loc.subfolders.s) {
                    UI.rows(TempPart.allCases) { part in
                        let node = area.child(named: part.rawValue)
                        UI.navRow(part.title.s, icon: .letter(part.rawValue), detail: part.detail.s,
                                  value: node.map { Fmt.bytes($0.bytes) } ?? "–", action: node.map { n in { model.open(n) } })
                    }
                }
            } else {
                UI.notMeasured()
            }
        }
    }
}
