import SwiftUI

/// Capacity of one mounted volume; external volumes can be measured and explored.
struct VolumeView: View {
    let path: String
    @Environment(AppModel.self) private var model

    var body: some View {
        if let v = model.volumes.first(where: { $0.path == path }) {
            UI.Page(.volume(path), title: v.name, options: { action(v) }) {
                UI.Card {
                    UI.VolumeSummary(v, segments: [
                        StorageSegment(id: StorageSegment.usedID, title: Loc.used.s, bytes: v.used - v.purgeable, colorIndex: CategoryKind.apps.rawValue),
                        StorageSegment(id: "purgeable", title: Loc.purgeable.s, bytes: v.purgeable, colorIndex: CategoryKind.purgeable.rawValue),
                    ])
                    Divider()
                    UI.Fields([UI.Field(.capacity, Fmt.bytes(v.total)), UI.Field(.used, Fmt.bytes(v.used - v.purgeable)),
                               UI.Field(.purgeable, Fmt.bytes(v.purgeable)), UI.Field(.freeSpace, Fmt.bytes(v.free)),
                               UI.Field(.available, Fmt.bytes(v.available)), UI.Field(.kind, v.format)])
                }
            }
        } else {
            UI.Placeholder(.empty(title: Loc.volumeGone.s, symbol: Symbols.volumeGone), in: .page)
        }
    }

    @ViewBuilder private func action(_ v: VolumeInfo) -> some View {
        if v.isRoot {
            UI.ActionButton(Loc.toOverview.s) { model.pane = .overview }
        } else if let node = model.root.descendant(at: v.path) {
            UI.ActionButton(Loc.exploreContents.s) { model.open(node) }
        } else {
            UI.ActionButton(Loc.scanAndExplore.s, .primary) {
                model.scan([v.path], reset: false)
                model.pane = .explorer
            }
            .disabled(model.scanning)
        }
    }
}
