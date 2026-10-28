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
    @AppStorage(SettingsKey.palette) private var palette = ChartPalette.colourful
    private static let row = "volume"

    var body: some View {
        Chart(segments) { s in
            BarMark(x: .value(Loc.columnSize.s, s.bytes), y: .value(Self.row, Self.row))  // one category row: a stacked bar
                .foregroundStyle(s.colorIndex.map { Theme.color($0, palette) } ?? Theme.freeSegment)
                .accessibilityLabel(s.title)
                .accessibilityValue(Fmt.bytes(s.bytes))
        }
        .chartXScale(domain: 0...max(total, segments.reduce(0) { $0 + $1.bytes }))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: Layout.storageBarHeight)
        .clipShape(RoundedRectangle(cornerRadius: Layout.storageBarRadius, style: .continuous))
    }
}

/// Volume name, available space and the stacked bar.
struct VolumeSummary: View {
    let volume: VolumeInfo
    let segments: [StorageSegment]

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            HeaderRow(icon: .file(volume.path), title: volume.name,
                      subtitle: Loc.availableOf.f(Fmt.bytes(volume.available), Fmt.bytes(volume.total)))
            StorageBar(segments: shown + [StorageSegment(id: "free", title: Loc.freeSpace.s, bytes: volume.free, colorIndex: nil)],
                       total: volume.total)
        }
        .padding(.vertical, Layout.rowPadding)
    }

    /// Before the first scan there are no categories yet; then the bar shows the whole used space in one piece.
    private var shown: [StorageSegment] {
        segments.isEmpty
            ? [StorageSegment(id: "used", title: Loc.used.s, bytes: volume.used, colorIndex: CategoryKind.system.rawValue)]
            : segments
    }
}

/// Size share as a native progress bar plus percentage, for table cells.
struct ShareCell: View {
    let fraction: Double

    var body: some View {
        HStack(spacing: 8) {
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
