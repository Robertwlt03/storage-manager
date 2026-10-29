import SwiftUI

/// A scrolling page: the header with the page's options and info button, then the content.
struct Page<Options: View, Content: View>: View {
    let title: String
    let info: Loc
    @ViewBuilder let options: Options
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                PageHeader(info: info) { options }
                content
            }
            .padding(Space.page)
            .frame(maxWidth: Layout.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .background(Backdrop())
        .navigationTitle(title)
    }
}

/// Always at the top of a page: its options on the left, an info button explaining the page on the right.
struct PageHeader<Options: View>: View {
    let info: Loc
    @ViewBuilder let options: Options
    @State private var showInfo = false

    var body: some View {
        HStack(spacing: Space.item) {
            options
            Spacer(minLength: 0)
            Button { showInfo.toggle() } label: { Label(Loc.aboutPage.s, systemImage: Symbols.info) }
                .labelStyle(.iconOnly)
                .appButton(.quiet)
                .font(.title3)
                .help(Loc.aboutPage.s)
                .popover(isPresented: $showInfo, arrowEdge: .bottom) {
                    Text(info.s)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Space.card)
                        .frame(width: Layout.popoverWidth, alignment: .leading)
                }
        }
        .frame(minHeight: Layout.headerHeight)
    }
}

/// Fills the visible height of a page and centres its content, for empty and loading states.
struct FillPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerRelativeFrame(.vertical, alignment: .center) { height, _ in height * Layout.fillShare }
    }
}

/// A rounded surface with an optional heading above it.
struct Card<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if let title { Text(title).font(.headline).padding(.leading, Space.xs) }
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.horizontal, Space.card)
                .padding(.vertical, Space.s)
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
            row(item).padding(.vertical, Space.row)
        }
    }
}
