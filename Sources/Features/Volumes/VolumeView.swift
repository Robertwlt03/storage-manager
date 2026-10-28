import SwiftUI

/// Capacity of one mounted volume; external volumes can be measured and explored.
struct VolumeView: View {
    let path: String
    @Environment(AppModel.self) private var model

    var body: some View {
        if let v = model.volumes.first(where: { $0.path == path }) {
            UI.page(.volume(path), title: v.name, options: { action(v) }) {
                UI.card {
                    UI.volume(v, segments: [
                        StorageSegment(id: StorageSegment.usedID, title: Loc.used.s, bytes: v.used - v.purgeable, colorIndex: CategoryKind.apps.rawValue),
                        StorageSegment(id: "purgeable", title: Loc.purgeable.s, bytes: v.purgeable, colorIndex: CategoryKind.purgeable.rawValue),
                    ])
                    Divider()
                    UI.fields([FieldItem(.capacity, Fmt.bytes(v.total)), FieldItem(.used, Fmt.bytes(v.used - v.purgeable)),
                               FieldItem(.purgeable, Fmt.bytes(v.purgeable)), FieldItem(.freeSpace, Fmt.bytes(v.free)),
                               FieldItem(.available, Fmt.bytes(v.available)), FieldItem(.kind, v.format)])
                }
            }
        } else {
            UI.empty(Loc.volumeGone.s, symbol: Symbols.volumeGone)
        }
    }

    @ViewBuilder private func action(_ v: VolumeInfo) -> some View {
        if v.isRoot {
            UI.button(Loc.toOverview.s) { model.pane = .overview }
        } else if let node = model.root.descendant(at: v.path) {
            UI.button(Loc.exploreContents.s) { model.open(node) }
        } else {
            UI.button(Loc.scanAndExplore.s, .primary) {
                model.scan([v.path], reset: false)
                model.pane = .explorer
            }
            .disabled(model.scanning)
        }
    }
}
