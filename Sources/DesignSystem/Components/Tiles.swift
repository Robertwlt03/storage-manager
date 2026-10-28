import SwiftUI

/// A tile for the grid view: large icon, name, size and an optional share bar.
struct Tile: View {
    let icon: RowIcon
    let title: String
    let value: String
    var detail: String?
    var share: Double?

    var body: some View {
        VStack(spacing: 8) {
            RowIconView(icon: icon, size: Layout.gridIcon)
            Text(title).font(.headline).lineLimit(2).multilineTextAlignment(.center)
            Text(value).monospacedDigit().foregroundStyle(.muted)
            if let detail { Text(detail).font(.callout).foregroundStyle(.muted).lineLimit(1) }
            if let share { ProgressView(value: min(max(share, 0), 1)).progressViewStyle(.linear) }
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity, minHeight: Layout.gridTile)
        .surface()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A figure with a label, for the statistics page.
struct StatTile: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        HStack(spacing: Layout.rowSpacing) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.tint).frame(width: Layout.badgeSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title2.weight(.semibold)).monospacedDigit()
                Text(label).foregroundStyle(.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(Layout.cardPadding)
        .surface()
        .accessibilityElement(children: .combine)
    }
}

/// Adaptive grid that fills the width with tiles.
struct TileGrid<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    var minWidth = Layout.gridTile
    @ViewBuilder let tile: (Data.Element) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth), spacing: Layout.spacing)], spacing: Layout.spacing) {
            ForEach(data) { tile($0) }
        }
    }
}
