import Charts
import SwiftUI

struct StorageSegment: Identifiable {
    let id: String
    let title: String
    let bytes: Int64
    let colorIndex: Int?  // nil = free space
}

/// Stacked bar like in System Settings › Storage.
struct StorageBar: View {
    let segments: [StorageSegment]
    let total: Int64
    private static let row = "volume"

    var body: some View {
        Chart(segments) { s in
            BarMark(x: .value(Loc.columnSize.s, s.bytes), y: .value(Self.row, Self.row))  // one category row: a stacked bar
                .foregroundStyle(s.colorIndex.map { Theme.color($0) } ?? Theme.freeSegment)
                .accessibilityLabel(s.title)
                .accessibilityValue(Fmt.bytes(s.bytes))
        }
        .chartXScale(domain: 0...max(total, segments.reduce(0) { $0 + $1.bytes }))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .staticChart()
        .frame(height: Layout.storageBarHeight)
        .clipShape(RoundedRectangle(cornerRadius: Layout.storageBarRadius, style: .continuous))
    }
}

/// Volume name, available space and the stacked bar.
struct VolumeSummary: View {
    let volume: VolumeInfo
    let segments: [StorageSegment]
    var onSelect: ((StorageSegment) -> Void)?
    var canSelect: (StorageSegment) -> Bool = { _ in true }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.section) {
            HeaderRow(icon: .file(volume.path), title: volume.name,
                      subtitle: Loc.availableOf.f(Fmt.bytes(volume.available), Fmt.bytes(volume.total)))
            let all = shown + [StorageSegment(id: "free", title: Loc.freeSpace.s, bytes: volume.free, colorIndex: nil)]
            StorageBar(segments: all, total: volume.total)
            StorageLegend(segments: all, onSelect: onSelect, canSelect: canSelect)
        }
        .padding(.vertical, Space.row)
    }

    /// Before the first scan there are no categories yet; then the bar shows the whole used space in one piece.
    private var shown: [StorageSegment] {
        segments.isEmpty
            ? [StorageSegment(id: "used", title: Loc.used.s, bytes: volume.used, colorIndex: CategoryKind.system.rawValue)]
            : segments
    }
}

/// Says which colour stands for what: the biggest parts by name, the rest grouped, free space last.
struct StorageLegend: View {
    let segments: [StorageSegment]
    var onSelect: ((StorageSegment) -> Void)?
    var canSelect: (StorageSegment) -> Bool = { _ in true }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: Layout.legendItemMin), alignment: .leading)], alignment: .leading, spacing: Space.s) {
            ForEach(items) { s in
                // Named categories lead to their folder; "Other" and free space have nowhere to go.
                let target = onSelect != nil && s.colorIndex != nil && s.id != Self.otherID && canSelect(s)
                Button { onSelect?(s) } label: {
                    HStack(spacing: Space.s) {
                        Circle().fill(s.colorIndex.map { Theme.color($0) } ?? Theme.freeSegment)
                            .frame(width: Layout.legendDot, height: Layout.legendDot)
                        Text(s.title).lineLimit(1)
                        Text(Fmt.bytes(s.bytes)).foregroundStyle(.muted).monospacedDigit().lineLimit(1)
                            .contentTransition(.numericText())
                        if target { Image(systemName: Symbols.chevron).font(.caption2.weight(.semibold)).foregroundStyle(.muted) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .allowsHitTesting(target)
                .font(.callout)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private static let otherID = "other"

    private var items: [StorageSegment] {
        let used = segments.filter { $0.colorIndex != nil }
        let free = segments.filter { $0.colorIndex == nil }
        guard used.count > Layout.legendMax else { return used + free }
        let rest = used.dropFirst(Layout.legendMax - 1)
        let other = StorageSegment(id: Self.otherID, title: Loc.otherCategories.s, bytes: rest.reduce(0) { $0 + $1.bytes },
                                   colorIndex: rest.first?.colorIndex)
        return Array(used.prefix(Layout.legendMax - 1)) + [other] + free
    }
}

/// Size share as a native progress bar plus percentage, for table cells.
struct ShareCell: View {
    let fraction: Double

    var body: some View {
        HStack(spacing: Space.s) {
            ProgressView(value: min(max(fraction, 0), 1)).progressViewStyle(.linear)
            Text(Fmt.percent(fraction)).monospacedDigit().frame(width: Layout.percentWidth, alignment: .trailing)
        }
    }
}

/// Finder icon and name, for table cells.
struct FileCell: View {
    let name: String
    let path: String?

    var body: some View {
        Label {
            Text(name).lineLimit(1).truncationMode(.middle)
        } icon: {
            if let path { FinderService.icon(path).resizable().frame(width: Layout.listIcon, height: Layout.listIcon) }
            else { Image(systemName: Symbols.rest) }
        }
    }
}

/// Right-aligned number for table cells.
struct NumberCell: View {
    let text: String
    var body: some View { Text(text).monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing) }
}
