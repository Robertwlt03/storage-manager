import SwiftUI

/// The start page: first how much space can be freed and how, then the disk split with its legend
/// (a click opens a category) and the history.
struct OverviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        UI.Page(.overview) {
            FreeUpCard()
            if let startupVolume = model.startupVolume { startupDiskCard(startupVolume) }
            HistoryCard()
        }
    }

    // MARK: Disk

    private func startupDiskCard(_ startupVolume: VolumeInformation) -> some View {
        UI.Card {
            UI.VolumeSummary(
                startupVolume, segments: segments, canSelect: canOpen, onSelect: open)
            if startupVolume.isLow {
                UI.Note(TextKey.lowSpaceWarning.translated, .warning(symbol: Symbols.lowSpace))
                    .padding(.bottom, Space.row)
            }
        }
    }

    private var segments: [StorageSegment] {
        model.categories.map { category in
            StorageSegment(
                id: "\(category.kind)", title: category.kind.title.translated,
                bytes: category.bytes, colorIndex: category.kind.rawValue)
        }
    }

    private func node(for segment: StorageSegment) -> Node? {
        model.categories.first { category in "\(category.kind)" == segment.id }?.node
    }

    private func canOpen(_ segment: StorageSegment) -> Bool { node(for: segment) != nil }

    private func open(_ segment: StorageSegment) { node(for: segment).map(model.open) }
}
