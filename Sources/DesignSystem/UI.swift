import SwiftUI

/// The component factory: every page builds its interface from these functions, so a design change
/// happens here once instead of on every page.
enum UI {
    static func page<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        Page(title: title, content: content)
    }

    static func card<C: View>(_ title: String? = nil, @ViewBuilder _ content: () -> C) -> some View {
        Card(title: title, content: content)
    }

    static func rows<D: RandomAccessCollection, R: View>(_ data: D, @ViewBuilder _ row: @escaping (D.Element) -> R) -> some View
    where D.Element: Identifiable {
        DividedRows(data: data, row: row)
    }

    static func navRow(_ title: String, icon: RowIcon? = nil, detail: String? = nil, value: String? = nil,
                       action: (() -> Void)? = nil) -> some View {
        NavRow(icon: icon, title: title, detail: detail, value: value, action: action)
    }

    /// Label/value rows with dividers; pass `FieldItem`s, optional ones as nil.
    static func fields(_ items: [FieldItem?]) -> some View {
        DividedRows(data: items.compactMap { $0 }) { FieldRow(label: $0.label, value: $0.value) }
    }

    static func header(_ title: String, subtitle: String, icon: RowIcon, size: CGFloat = Layout.headerIcon) -> some View {
        HeaderRow(icon: icon, title: title, subtitle: subtitle, iconSize: size)
    }

    static func note(_ text: String) -> some View { Note(text: text) }
    static func progress(_ text: String) -> some View { ProgressLine(text: text) }
    static func status(_ text: String, symbol: String, _ kind: StatusLabel.Kind) -> some View {
        StatusLabel(text: text, symbol: symbol, kind: kind)
    }

    static func notMeasured() -> some View { NotMeasured() }
    static func emptyOrScanning(_ title: String, symbol: String, detail: String? = nil) -> some View {
        EmptyOrScanning(title: title, symbol: symbol, detail: detail)
    }
    static func scanBanner() -> some View { ScanBanner() }

    // Grid
    static func tile(icon: RowIcon, title: String, value: String, detail: String? = nil, share: Double? = nil) -> some View {
        Tile(icon: icon, title: title, value: value, detail: detail, share: share)
    }
    static func grid<D: RandomAccessCollection, C: View>(_ data: D, minWidth: CGFloat = Layout.gridTile,
                                                         @ViewBuilder _ tile: @escaping (D.Element) -> C) -> some View
    where D.Element: Identifiable {
        TileGrid(data: data, minWidth: minWidth, tile: tile)
    }
    /// Grid for a fixed set of tiles.
    static func tiles<C: View>(minWidth: CGFloat = Layout.gridTile, @ViewBuilder _ content: () -> C) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth), spacing: Layout.spacing)], spacing: Layout.spacing) { content() }
    }
    static func stat(_ value: String, _ label: Loc, symbol: String) -> some View { StatTile(value: value, label: label.s, symbol: symbol) }
    static func legend(_ segments: [StorageSegment]) -> some View { StorageLegend(segments: segments) }

    static func empty(_ title: String, symbol: String, detail: String? = nil) -> some View {
        EmptyState(title: title, symbol: symbol, detail: detail) { EmptyView() }
    }

    static func button(_ title: String, _ kind: ButtonKind = .normal, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(title, role: role, action: action).appButton(kind)
    }

    static func volume(_ v: VolumeInfo, segments: [StorageSegment]) -> some View { VolumeSummary(volume: v, segments: segments) }

    // Table cells
    static func fileCell(_ e: Entry) -> some View { FileCell(name: e.name, path: e.path) }
    static func sizeCell(_ bytes: Int64) -> some View { NumberCell(text: Fmt.bytes(bytes)) }
    static func countCell(_ n: Int) -> some View { NumberCell(text: Fmt.count(n)) }
    static func shareCell(_ part: Int64, of whole: Int64) -> some View { ShareCell(fraction: Double(part) / Double(max(whole, 1))) }
}
