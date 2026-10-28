import SwiftUI

/// A tile for the grid view: large icon, name, size and an optional share bar.
struct Tile: View {
    let icon: RowIcon
    let title: String
    let value: String
    var detail: String?
    var share: Double?

    var body: some View {
        VStack(spacing: Space.s) {
            RowIconView(icon: icon, size: Layout.gridIcon)
            Text(title).font(.headline).lineLimit(2).multilineTextAlignment(.center)
            Text(value).monospacedDigit().foregroundStyle(.muted)
            if let detail { Text(detail).font(.callout).foregroundStyle(.muted).lineLimit(1) }
            if let share { ProgressView(value: min(max(share, 0), 1)).progressViewStyle(.linear) }
        }
        .padding(Space.card)
        .frame(maxWidth: .infinity, minHeight: Layout.gridTile)
        .surface()
        .contentShape(Rectangle())
        .hoverLift()
        .accessibilityElement(children: .combine)
    }
}

/// A figure with a label, for the statistics page.
struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    var action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: Space.item) {
                Image(systemName: symbol).font(.title2).foregroundStyle(.tint).frame(width: Layout.badgeSize)
                VStack(alignment: .leading, spacing: Space.hairline) {
                    Text(value).font(.title2.weight(.semibold)).monospacedDigit().contentTransition(.numericText())
                    Text(label).foregroundStyle(.muted)
                }
                Spacer(minLength: 0)
                if action != nil { Image(systemName: Symbols.chevron).font(.caption.weight(.semibold)).foregroundStyle(.muted) }
            }
            .padding(Space.card)
            .surface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverLift()
        .allowsHitTesting(action != nil)
        .accessibilityElement(children: .combine)
    }
}

/// Adaptive grid that fills the width with tiles.
struct TileGrid<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    var minWidth = Layout.gridTile
    @ViewBuilder let tile: (Data.Element) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth), spacing: Space.section)], spacing: Space.section) {
            ForEach(data) { tile($0) }
        }
    }
}
