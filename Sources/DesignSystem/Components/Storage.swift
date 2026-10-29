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
                StorageBar(segments: wholeVolume, total: volume.total)
                StorageLegend(segments: wholeVolume, onSelect: onSelect, canSelect: canSelect)
            }
            .padding(.vertical, Space.row)
        }

        /// Every part of the volume: the categories, used space they do not cover, and free space.
        private var wholeVolume: [StorageSegment] {
            let freeSpace = StorageSegment(
                id: "free", title: TextKey.freeSpace.translated, bytes: volume.free, colorIndex: nil
            )
            return withUncoveredSpace + [freeSpace]
        }

        /// Used space no category covers yet stays one piece, so the bar always spans the whole volume.
        private var withUncoveredSpace: [StorageSegment] {
            let covered = segments.reduce(0) { total, segment in total + segment.bytes }
            let uncovered = volume.used - covered
            guard uncovered > 0 else { return segments }
            let uncoveredSpace = StorageSegment(
                id: StorageSegment.usedID, title: TextKey.used.translated, bytes: uncovered,
                colorIndex: CategoryKind.system.rawValue)
            return segments + [uncoveredSpace]
        }
    }
}

/// Plain shapes instead of a chart: they follow width changes frame by frame without redrawing a chart.
private struct StorageBar: View {
    let segments: [StorageSegment]
    let total: Int64

    var body: some View {
        let barBytes = self.barBytes
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(segments) { segment in
                    Rectangle()
                        .fill(segment.color)
                        .frame(width: geometry.size.width * segment.shownBytes / barBytes)
                        .accessibilityElement()
                        .accessibilityLabel(segment.title)
                        .accessibilityValue(Format.bytes(segment.bytes))
                }
            }
        }
        .frame(height: Layout.storageBarHeight)
        .clipShape(RoundedRectangle(cornerRadius: Layout.storageBarRadius, style: .continuous))
    }

    /// The bytes the whole bar stands for: the volume, or more if the parts add up to more.
    private var barBytes: CGFloat {
        let parts = segments.reduce(0) { total, segment in total + max(segment.bytes, 0) }
        return CGFloat(max(total, parts, 1))
    }
}

extension StorageSegment {
    /// Free space is grey, every other part has its category colour.
    fileprivate var color: Color { colorIndex.map(Theme.color) ?? Theme.freeSegment }

    /// A negative size, which a measurement can briefly report, shows as nothing.
    fileprivate var shownBytes: CGFloat { CGFloat(max(bytes, 0)) }
}

/// The biggest parts by name, the rest grouped, free space last; in a fixed number of columns, because an adaptive
/// grid jumped between two and three columns halfway through the sidebar animation.
private struct StorageLegend: View {
    let segments: [StorageSegment]
    var onSelect: ((StorageSegment) -> Void)?
    var canSelect: (StorageSegment) -> Bool

    /// When the legend is full, the last place goes to the entry that groups the rest.
    private static let namedEntryLimit = Layout.legendMax - 1

    var body: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), alignment: .leading), count: Layout.legendColumns)
        LazyVGrid(columns: columns, alignment: .leading, spacing: Space.small) {
            ForEach(entries) { segment in entry(for: segment) }
        }
    }

    private func entry(for segment: StorageSegment) -> some View {
        let leadsSomewhere = leadsSomewhere(segment)
        return Button {
            onSelect?(segment)
        } label: {
            HStack(spacing: Space.small) {
                UI.Icon(.dot(segment.color), size: .extraSmall)
                Text(segment.title).lineLimit(1)
                Text(Format.bytes(segment.bytes)).foregroundStyle(.muted).monospacedDigit()
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

    /// Categories lead to their page; free space, uncovered space and the grouped rest do not.
    private func leadsSomewhere(_ segment: StorageSegment) -> Bool {
        let isCategory = segment.colorIndex != nil && segment.id != StorageSegment.otherID
        return onSelect != nil && isCategory && canSelect(segment)
    }

    private var entries: [StorageSegment] {
        let named = segments.filter { segment in !isListedLast(segment) }
        let listedLast = segments.filter(isListedLast)
        guard named.count > Layout.legendMax else { return named + listedLast }
        let rest = named.dropFirst(Self.namedEntryLimit)
        let other = StorageSegment(
            id: StorageSegment.otherID, title: TextKey.otherCategories.translated,
            bytes: rest.reduce(0) { total, segment in total + segment.bytes },
            colorIndex: rest.first?.colorIndex)
        return Array(named.prefix(Self.namedEntryLimit)) + [other] + listedLast
    }

    /// Free space and used space no category covers come after the categories.
    private func isListedLast(_ segment: StorageSegment) -> Bool {
        segment.colorIndex == nil || segment.id == StorageSegment.usedID
    }
}
