import SwiftUI

/// A scrolling page with the backdrop and a readable maximum width.
struct Page<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.spacing) { content }
                .padding(Layout.pagePadding)
                .frame(maxWidth: Layout.maxContentWidth)
                .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .background(Backdrop())
        .navigationTitle(title)
    }
}

/// A rounded surface with an optional heading above it.
struct Card<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { Text(title).font(.headline).padding(.leading, 4) }
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.horizontal, Layout.cardPadding)
                .padding(.vertical, Layout.cardPadding / 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .surface()
        }
    }
}

/// Rows with a divider between them, the way grouped lists look on macOS.
struct DividedRows<Data: RandomAccessCollection, Row: View>: View where Data.Element: Identifiable {
    let data: Data
    @ViewBuilder let row: (Data.Element) -> Row

    var body: some View {
        ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
            if index > 0 { Divider() }
            row(item).padding(.vertical, Layout.rowPadding)
        }
    }
}
