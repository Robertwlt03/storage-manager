import SwiftUI

extension UI {
    /// A tile of the grid view: large icon, name, size and an optional share bar.
    struct Tile: View {
        let icon: IconKind
        let title: String
        let value: String
        var detail: String?
        var share: Double?

        var body: some View {
            VStack(spacing: Space.small) {
                Icon(icon, size: .large)
                Text(title).textRole(.section).lineLimit(Layout.maximumWrappedLines)
                    .multilineTextAlignment(.center)
                Text(value).textRole(.value)
                if let detail { Text(detail).textRole(.hint).lineLimit(1) }
                if let share {
                    ProgressView(value: Fraction.clamp(share)).progressViewStyle(.linear)
                }
            }
            .padding(Space.card)
            .frame(maxWidth: .infinity, minHeight: Layout.gridTileSize)
            .surface()
            .contentShape(Rectangle())
            .hoverLift()
            .accessibilityElement(children: .combine)
        }
    }

    /// As many tiles per row as fit.
    struct TileGrid<Data: RandomAccessCollection, Content: View>: View
    where Data.Element: Identifiable {
        let data: Data
        @ViewBuilder let tile: (Data.Element) -> Content

        init(_ data: Data, @ViewBuilder _ tile: @escaping (Data.Element) -> Content) {
            self.data = data
            self.tile = tile
        }

        var body: some View {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: Layout.gridTileSize), spacing: Space.section)
                ],
                spacing: Space.section
            ) {
                ForEach(data) { item in tile(item) }
            }
        }
    }
}
