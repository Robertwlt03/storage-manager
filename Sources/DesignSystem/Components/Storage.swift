import SwiftUI

struct StorageSegment: Identifiable {
    let id: String
    let title: String
    let bytes: Int64
    let colorIndex: Int?  // nil = free space

    static let usedID = "used"  // used space no category covers (yet)
}

/// Stacked bar like in System Settings › Storage. Plain shapes instead of a chart: when the sidebar or the window
/// changes the width, they follow frame by frame without redrawing a whole chart each time.
struct StorageBar: View {
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
                        .accessibilityValue(Fmt.bytes(s.bytes))
                }
            }
        }
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

    /// Used space the categories do not cover yet stays one piece: all of it before the first scan, a shrinking
    /// part while scanning. So the bar always spans the whole volume and only its split changes.
    private var shown: [StorageSegment] {
        let rest = volume.used - segments.reduce(0) { $0 + $1.bytes }
        guard rest > 0 else { return segments }
        return segments + [StorageSegment(id: StorageSegment.usedID, title: Loc.used.s, bytes: rest,
                                          colorIndex: CategoryKind.system.rawValue)]
    }
}

/// Says which colour stands for what: the biggest parts by name, the rest grouped, free space last.
struct StorageLegend: View {
    let segments: [StorageSegment]
    var onSelect: ((StorageSegment) -> Void)?
    var canSelect: (StorageSegment) -> Bool = { _ in true }

    var body: some View {
        // A fixed number of columns: an adaptive grid would jump from two to three columns halfway through the
        // sidebar animation and move every entry at once.
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: Layout.legendColumns),
                  alignment: .leading, spacing: Space.s) {
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
                        if target { Chevron() }
                    }
                    .contentShape(Rectangle())
                }
                .appButton(.content)
                .allowsHitTesting(target)
                .font(.callout)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private static let otherID = "other"

    private var items: [StorageSegment] {
        // The uncovered used space and free space always keep their own entries at the end.
        let used = segments.filter { $0.colorIndex != nil && $0.id != StorageSegment.usedID }
        let free = segments.filter { $0.colorIndex == nil || $0.id == StorageSegment.usedID }
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
            IconView(icon: path.map(Icon.file) ?? .symbol(Symbols.rest), size: .small)
        }
    }
}

/// Right-aligned number for table cells.
struct NumberCell: View {
    let text: String
    var body: some View { Text(text).monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing) }
}
