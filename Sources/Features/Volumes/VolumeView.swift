import SwiftUI

/// Capacity of one mounted volume; external volumes can be measured and explored.
struct VolumeView: View {
    let path: String
    @Environment(AppModel.self) private var model

    private var volume: VolumeInformation? { model.volumes.first { volume in volume.path == path } }

    var body: some View {
        // The startup disk is the Overview's; an external one can be measured and explored here.
        if let volume, volume.isRoot {
            UI.Page(.volume(path), title: volume.name) { volumeCard(volume) }
        } else if let volume {
            UI.Page(
                .volume(path), title: volume.name, options: { primaryAction(volume) },
                { volumeCard(volume) })
        } else {
            UI.Placeholder(
                .empty(title: TextKey.volumeGone.translated, symbol: Symbols.volumeGone), in: .page)
        }
    }

    private func volumeCard(_ volume: VolumeInformation) -> some View {
        UI.Card { UI.VolumeSummary(volume, segments: segments(of: volume)) }
    }

    /// Used space without what macOS can purge on demand.
    private func usedBytes(of volume: VolumeInformation) -> Int64 {
        volume.usedBytes - volume.purgeableBytes
    }

    private func segments(of volume: VolumeInformation) -> [StorageSegment] {
        [
            StorageSegment(
                id: StorageSegment.usedID, title: TextKey.used.translated,
                bytes: usedBytes(of: volume), colorIndex: CategoryKind.apps.rawValue),
            StorageSegment(
                id: "purgeable", title: TextKey.purgeable.translated,
                bytes: volume.purgeableBytes, colorIndex: CategoryKind.purgeable.rawValue),
        ]
    }

    @ViewBuilder private func primaryAction(_ volume: VolumeInformation) -> some View {
        if let node = model.root.descendant(at: volume.path) {
            UI.ActionButton(TextKey.exploreContents.translated) { model.open(node) }
        } else {
            UI.ActionButton(TextKey.scanAndExplore.translated, .primary) {
                model.scan([volume.path], reset: false)
                model.pane = .explorer
            }
            .disabled(model.isScanning)
        }
    }
}
