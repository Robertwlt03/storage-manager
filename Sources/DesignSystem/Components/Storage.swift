import SwiftUI

struct StorageSegment: Identifiable {
    let id: String
    let title: String
    let bytes: Int64
    let colorIndex: Int?  // nil = free space

    static let usedID = "used"  // used space no category covers yet
    static let otherID = "other"
}

extension UI {
    /// Volume name, available space, the stacked bar and its legend, like System Settings › Storage.
    struct VolumeSummary: View {
        let volume: VolumeInfo
        let segments: [StorageSegment]
        var canSelect: (StorageSegment) -> Bool
        var onSelect: ((StorageSegment) -> Void)?

        init(
            _ volume: VolumeInfo, segments: [StorageSegment],
            canSelect: @escaping (StorageSegment) -> Bool = { _ in false },
            onSelect: ((StorageSegment) -> Void)? = nil
        ) {
            self.volume = volume
            self.segments = segments
            self.canSelect = canSelect
            self.onSelect = onSelect
        }

        var body: some View {
            VStack(alignment: .leading, spacing: Space.section) {
                TitleRow(
                    volume.name,
                    subtitle: TextKey.availableOf.translated(
                        with: Format.bytes(volume.available), Format.bytes(volume.total)),
                    icon: .file(volume.path))
                let all =
                    withUncoveredSpace + [
                        StorageSegment(
                            id: "free", title: TextKey.freeSpace.translated, bytes: volume.free,
                            colorIndex: nil)
                    ]
                StorageBar(segments: all, total: volume.total)
                StorageLegend(segments: all, onSelect: onSelect, canSelect: canSelect)
            }
            .padding(.vertical, Space.row)
        }

        /// Used space no category covers yet stays one piece, so the bar always spans the whole volume.
        private var withUncoveredSpace: [StorageSegment] {
            let rest = volume.used - segments.reduce(0) { $0 + $1.bytes }
            guard rest > 0 else { return segments }
            return segments + [
                StorageSegment(
                    id: StorageSegment.usedID, title: TextKey.used.translated, bytes: rest,
                    colorIndex: CategoryKind.system.rawValue)
            ]
        }
    }
}

/// Plain shapes instead of a chart: they follow width changes frame by frame without redrawing a chart.
private struct StorageBar: View {
    let segments: [StorageSegment]
    let total: Int64

    var body: some View {
        let sum = CGFloat(max(total, segments.reduce(0) { $0 + max($1.bytes, 0) }, 1))
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(segments) { s in
                    Rectangle()
                        .fill(s.colorIndex.map { Theme.color($0) } ?? Theme.freeSegment)
                        .frame(width: geo.size.width * CGFloat(max(s.bytes, 0)) / sum)
                        .accessibilityElement()
                        .accessibilityLabel(s.title)
                        .accessibilityValue(Format.bytes(s.bytes))
                }
            }
        }
        .frame(height: Layout.storageBarHeight)
        .clipShape(RoundedRectangle(cornerRadius: Layout.storageBarRadius, style: .continuous))
    }
}

/// The biggest parts by name, the rest grouped, free space last; in a fixed number of columns, because an adaptive
/// grid jumped between two and three columns halfway through the sidebar animation.
private struct StorageLegend: View {
    let segments: [StorageSegment]
    var onSelect: ((StorageSegment) -> Void)?
    var canSelect: (StorageSegment) -> Bool

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), alignment: .leading), count: Layout.legendColumns),
            alignment: .leading, spacing: Space.small
        ) {
            ForEach(entries) { s in
                let leadsSomewhere =
                    onSelect != nil && s.colorIndex != nil && s.id != StorageSegment.otherID
                    && canSelect(s)
                Button {
                    onSelect?(s)
                } label: {
                    HStack(spacing: Space.small) {
                        UI.Icon(
                            .dot(s.colorIndex.map { Theme.color($0) } ?? Theme.freeSegment),
                            size: .extraSmall)
                        Text(s.title).lineLimit(1)
                        Text(Format.bytes(s.bytes)).foregroundStyle(.muted).monospacedDigit()
                            .lineLimit(1)
                            .contentTransition(.numericText())
                        if leadsSomewhere { UI.Chevron() }
                    }
                    .contentShape(Rectangle())
                }
                .appButton(.content)
                .allowsHitTesting(leadsSomewhere)
                .font(.callout)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var entries: [StorageSegment] {
        let named = segments.filter { $0.colorIndex != nil && $0.id != StorageSegment.usedID }
        let atTheEnd = segments.filter { $0.colorIndex == nil || $0.id == StorageSegment.usedID }
        guard named.count > Layout.legendMax else { return named + atTheEnd }
        let rest = named.dropFirst(Layout.legendMax - 1)
        let other = StorageSegment(
            id: StorageSegment.otherID, title: TextKey.otherCategories.translated,
            bytes: rest.reduce(0) { $0 + $1.bytes },
            colorIndex: rest.first?.colorIndex)
        return Array(named.prefix(Layout.legendMax - 1)) + [other] + atTheEnd
    }
}
