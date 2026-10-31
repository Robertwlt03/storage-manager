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

    /// A key figure with its label, leading to the page with the details.
    struct KeyFigure: View {
        let value: String
        let label: String
        let symbol: String
        let isLoading: Bool
        let action: () -> Void

        init(
            _ value: String, _ label: String, symbol: String, isLoading: Bool,
            action: @escaping () -> Void
        ) {
            self.value = value
            self.label = label
            self.symbol = symbol
            self.isLoading = isLoading
            self.action = action
        }

        var body: some View {
            Button(action: action) {
                HStack(spacing: Space.item) {
                    figure
                    Spacer(minLength: 0)
                    Chevron()
                }
                .padding(Space.card)
                .surface()
                .contentShape(Rectangle())
            }
            .appButton(.content)
            .hoverLift()
            .allowsHitTesting(!isLoading)
            .accessibilityElement(children: .combine)
        }

        private var figure: some View {
            VStack(alignment: .leading, spacing: Space.hairline) {
                Icon(.symbol(symbol), size: .small).foregroundStyle(.tint)
                    .padding(.bottom, Space.extraSmall)
                Text(value).textRole(.figure).contentTransition(.numericText())
                    .lineLimit(1).minimumScaleFactor(Layout.keyFigureMinimumScale)
                    .calculating(isLoading)
                Text(label).foregroundStyle(.muted)
                    .lineLimit(Layout.maximumWrappedLines, reservesSpace: true)
            }
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

    /// A fixed number of equally wide columns.
    struct FixedGrid<Content: View>: View {
        let columns: Int
        @ViewBuilder let content: Content

        init(columns: Int, @ViewBuilder _ content: () -> Content) {
            self.columns = columns
            self.content = content()
        }

        var body: some View {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: Space.section), count: columns),
                spacing: Space.section
            ) { content }
        }
    }
}
