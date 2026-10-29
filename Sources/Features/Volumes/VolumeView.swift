import SwiftUI

/// Capacity of one mounted volume; external volumes can be measured and explored.
struct VolumeView: View {
    let path: String
    @Environment(AppModel.self) private var model

    var body: some View {
        if let v = model.volumes.first(where: { $0.path == path }) {
            UI.Page(.volume(path), title: v.name, options: { action(v) }) {
                UI.Card {
                    UI.VolumeSummary(
                        v,
                        segments: [
                            StorageSegment(
                                id: StorageSegment.usedID, title: TextKey.used.translated,
                                bytes: v.used - v.purgeable, colorIndex: CategoryKind.apps.rawValue),
                            StorageSegment(
                                id: "purgeable", title: TextKey.purgeable.translated,
                                bytes: v.purgeable, colorIndex: CategoryKind.purgeable.rawValue),
                        ])
                    Divider()
                    UI.Fields([
                        UI.Field(.capacity, Format.bytes(v.total)),
                        UI.Field(.used, Format.bytes(v.used - v.purgeable)),
                        UI.Field(.purgeable, Format.bytes(v.purgeable)),
                        UI.Field(.freeSpace, Format.bytes(v.free)),
                        UI.Field(.available, Format.bytes(v.available)), UI.Field(.kind, v.format),
                    ])
                }
            }
        } else {
            UI.Placeholder(
                .empty(title: TextKey.volumeGone.translated, symbol: Symbols.volumeGone), in: .page)
        }
    }

    @ViewBuilder private func action(_ v: VolumeInfo) -> some View {
        if v.isRoot {
            UI.ActionButton(TextKey.toOverview.translated) { model.pane = .overview }
        } else if let node = model.root.descendant(at: v.path) {
            UI.ActionButton(TextKey.exploreContents.translated) { model.open(node) }
        } else {
            UI.ActionButton(TextKey.scanAndExplore.translated, .primary) {
                model.scan([v.path], reset: false)
                model.pane = .explorer
            }
            .disabled(model.scanning)
        }
    }
}
