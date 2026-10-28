import SwiftUI

/// The component factory: every page builds its interface from these functions, so a design change
/// happens here once instead of on every page.
enum UI {
    static func page<C: View>(_ pane: Pane, title: String? = nil, @ViewBuilder _ content: () -> C) -> some View {
        Page(title: title ?? pane.title.s, info: pane.info, options: { EmptyView() }, content: content)
    }

    static func page<O: View, C: View>(_ pane: Pane, title: String? = nil, @ViewBuilder options: () -> O,
                                       @ViewBuilder _ content: () -> C) -> some View {
        Page(title: title ?? pane.title.s, info: pane.info, options: options, content: content)
    }

    /// The page header on its own, above tables (which bring their own scrolling).
    static func header<O: View>(_ info: Loc, @ViewBuilder options: () -> O) -> some View {
        PageHeader(info: info, options: options)
            .padding(.horizontal, Space.page)
            .padding(.vertical, Space.row)
    }

    /// An option menu that always shows its current choice next to its name.
    static func menu<V: Hashable, C: View>(_ title: Loc, selection: Binding<V>, @ViewBuilder _ items: () -> C) -> some View {
        Picker(selection: selection, content: items) { Text(title.s) }
            .pickerStyle(.menu)
            .fixedSize()
    }

    /// A compact segmented control without a label, for a few choices that sit next to each other.
    static func segments<V: Hashable, C: View>(selection: Binding<V>, @ViewBuilder _ items: () -> C) -> some View {
        Picker(selection: selection, content: items) { EmptyView() }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
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

    /// Full-size, centred states for pages without content.
    static func notMeasured() -> some View { FillPage { NotMeasured() } }
    /// The same state inside a card, below other content.
    static func notMeasuredCard(_ title: String) -> some View {
        Card(title: title) { NotMeasured().frame(maxWidth: .infinity, minHeight: Layout.placeholderHeight) }
    }
    static func pendingBlock(height: CGFloat = Layout.chartHeight) -> some View { PendingBlock(height: height) }
    static func emptyOrScanning(_ title: String, symbol: String, detail: String? = nil) -> some View {
        EmptyOrScanning(title: title, symbol: symbol, detail: detail)
    }

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
    static func tiles<C: View>(columns: Int, @ViewBuilder _ content: () -> C) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.section), count: columns), spacing: Space.section) {
            content()
        }
    }
    static func stat(_ value: String, _ label: String, symbol: String, loading: Bool = false,
                     action: (() -> Void)? = nil) -> some View {
        StatTile(value: value, label: label, symbol: symbol, loading: loading, action: action)
    }
    static func caption(_ text: String) -> some View { Note(text: text) }

    static func empty(_ title: String, symbol: String, detail: String? = nil) -> some View {
        FillPage { EmptyState(title: title, symbol: symbol, detail: detail) { EmptyView() } }
    }

    static func button(_ title: String, _ kind: ButtonKind = .normal, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(title, role: role, action: action).appButton(kind)
    }

    static func volume(_ v: VolumeInfo, segments: [StorageSegment], canSelect: @escaping (StorageSegment) -> Bool = { _ in false },
                       onSelect: ((StorageSegment) -> Void)? = nil) -> some View {
        VolumeSummary(volume: v, segments: segments, onSelect: onSelect, canSelect: canSelect)
    }

    // Table cells
    static func fileCell(_ e: Entry) -> some View { FileCell(name: e.name, path: e.path) }
    static func sizeCell(_ bytes: Int64) -> some View { NumberCell(text: Fmt.bytes(bytes)) }
    static func countCell(_ n: Int) -> some View { NumberCell(text: Fmt.count(n)) }
    static func shareCell(_ part: Int64, of whole: Int64) -> some View { ShareCell(fraction: Double(part) / Double(max(whole, 1))) }
}
