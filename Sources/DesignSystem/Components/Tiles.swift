import SwiftUI

/// A tile for the grid view: large icon, name, size and an optional share bar.
struct Tile: View {
    let icon: Icon
    let title: String
    let value: String
    var detail: String?
    var share: Double?

    var body: some View {
        VStack(spacing: Space.s) {
            IconView(icon: icon, size: .large)
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

/// A figure with a label, for the key figures on the start page.
struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    var loading = false  // the value is still being calculated
    var action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: Space.item) {
                // The symbol sits above the figure, so number and label get the tile's whole width even when narrow.
                VStack(alignment: .leading, spacing: Space.hairline) {
                    IconView(icon: .symbol(symbol), size: .small).foregroundStyle(.tint).padding(.bottom, Space.xs)
                    Text(value).font(.title2.weight(.semibold)).monospacedDigit().contentTransition(.numericText())
                        .lineLimit(1).minimumScaleFactor(Layout.statMinScale)  // a number never breaks
                        .calculating(loading)
                    Text(label).foregroundStyle(.muted).lineLimit(2, reservesSpace: true)  // same height in every tile
                }
                Spacer(minLength: 0)
                if action != nil { Chevron() }
            }
            .padding(Space.card)
            .surface()
            .contentShape(Rectangle())
        }
        .appButton(.content)
        .hoverLift()
        .allowsHitTesting(action != nil && !loading)
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
