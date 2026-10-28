import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.layoutMode) private var layout = LayoutMode.list

    var body: some View {
        UI.page(Loc.paneOverview.s) {
            if let v = model.startupVolume {
                UI.card { UI.volume(v, segments: segments) }
            }
            if model.categories.isEmpty {
                UI.card(Loc.categories.s) { UI.notMeasured().frame(minHeight: Layout.placeholderHeight) }
            } else if layout == .grid {
                Text(Loc.categories.s).font(.headline).padding(.leading, 4)
                UI.grid(model.categories) { c in
                    UI.tile(icon: badge(c), title: c.kind.title.s, value: Fmt.bytes(c.bytes))
                        .onTapGesture { c.node.map(model.open) }
                }
            } else {
                UI.card(Loc.categories.s) {
                    UI.rows(model.categories) { c in
                        UI.navRow(c.kind.title.s, icon: badge(c), value: Fmt.bytes(c.bytes), action: c.node.map { n in { model.open(n) } })
                    }
                }
            }
            if !model.categories.isEmpty { UI.note(Loc.overviewNote.s) }
        }
    }

    private func badge(_ c: Category) -> RowIcon { .badge(symbol: c.kind.symbol, colorIndex: c.kind.rawValue) }

    private var segments: [StorageSegment] {
        model.categories.map { StorageSegment(id: "\($0.kind)", title: $0.kind.title.s, bytes: $0.bytes, colorIndex: $0.kind.rawValue) }
    }
}
