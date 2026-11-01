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
            if startupVolume.purgeableBytes > 0 {
                UI.Note(TextKey.availableExplained.translated, .hint).padding(.bottom, Space.row)
            }
            if startupVolume.isLow {
                UI.Note(TextKey.lowSpaceWarning.translated, .warning(symbol: Symbols.lowSpace))
                    .padding(.bottom, Space.row)
            }
        }
    }

    /// Biggest first, but what macOS can delete comes last, next to the free space: together they
    /// are the space the card calls available.
    private var segments: [StorageSegment] {
        let purgeableLast = model.categories.sorted { left, right in
            left.kind != .purgeable && right.kind == .purgeable
        }
        return purgeableLast.map { category in
            StorageSegment(
                id: "\(category.kind)", title: category.kind.title.translated,
                bytes: category.bytes, colorIndex: category.kind.rawValue)
        }
    }

    private func category(for segment: StorageSegment) -> Category? {
        model.categories.first { category in "\(category.kind)" == segment.id }
    }

    private func canOpen(_ segment: StorageSegment) -> Bool {
        category(for: segment)?.folders.isEmpty == false
    }

    private func open(_ segment: StorageSegment) { category(for: segment).map(model.open) }
}
