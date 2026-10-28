import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        UI.page(Loc.paneOverview.s) {
            if let v = model.startupVolume {
                UI.card { UI.volume(v, segments: segments) }
            }
            UI.card(Loc.categories.s) {
                if model.categories.isEmpty { UI.notMeasured().frame(minHeight: Layout.placeholderHeight) }
                UI.rows(model.categories) { c in
                    UI.navRow(c.kind.title.s, icon: .badge(symbol: c.kind.symbol, colorIndex: c.kind.rawValue),
                              value: Fmt.bytes(c.bytes), action: c.node.map { n in { model.open(n) } })
                }
            }
            if !model.categories.isEmpty { UI.note(Loc.overviewNote.s) }
        }
    }

    private var segments: [StorageSegment] {
        model.categories.map { StorageSegment(id: "\($0.kind)", title: $0.kind.title.s, bytes: $0.bytes, colorIndex: $0.kind.rawValue) }
    }
}
