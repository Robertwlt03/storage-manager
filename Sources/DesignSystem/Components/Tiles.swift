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
                Text(title).textRole(.section).lineLimit(2).multilineTextAlignment(.center)
                Text(value).textRole(.value)
                if let detail { Text(detail).textRole(.hint).lineLimit(1) }
                if let share {
                    ProgressView(value: min(max(share, 0), 1)).progressViewStyle(.linear)
                }
            }
            .padding(Space.card)
            .frame(maxWidth: .infinity, minHeight: Layout.gridTile)
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
        var loading = false
        var action: (() -> Void)?

        init(
            _ value: String, _ label: String, symbol: String, loading: Bool = false,
            action: (() -> Void)? = nil
        ) {
            self.value = value
            self.label = label
            self.symbol = symbol
            self.loading = loading
            self.action = action
        }

        var body: some View {
            Button {
                action?()
            } label: {
                HStack(spacing: Space.item) {
                    VStack(alignment: .leading, spacing: Space.hairline) {
                        Icon(.symbol(symbol), size: .small).foregroundStyle(.tint)
                            .padding(.bottom, Space.extraSmall)
                        Text(value).textRole(.figure).contentTransition(.numericText())
                            .lineLimit(1).minimumScaleFactor(Layout.statMinScale)
                            .calculating(loading)
                        Text(label).foregroundStyle(.muted).lineLimit(2, reservesSpace: true)
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

    /// As many tiles per row as fit.
    struct TileGrid<Data: RandomAccessCollection, Content: View>: View
    where Data.Element: Identifiable {
        let data: Data
        var minWidth = Layout.gridTile
        @ViewBuilder let tile: (Data.Element) -> Content

        init(
            _ data: Data, minWidth: CGFloat = Layout.gridTile,
            @ViewBuilder _ tile: @escaping (Data.Element) -> Content
        ) {
            self.data = data
            self.minWidth = minWidth
            self.tile = tile
        }

        var body: some View {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: minWidth), spacing: Space.section)],
                spacing: Space.section
            ) {
                ForEach(data) { tile($0) }
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
