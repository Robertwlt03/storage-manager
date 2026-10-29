import SwiftUI

extension UI {
    /// A scrolling page: its header with options and info button, then the content.
    struct Page<Options: View, Content: View>: View {
        let title: String
        let info: Loc
        @ViewBuilder let options: Options
        @ViewBuilder let content: Content

        init(_ pane: Pane, title: String? = nil, @ViewBuilder options: () -> Options, @ViewBuilder _ content: () -> Content) {
            self.title = title ?? pane.title.s
            info = pane.info
            self.options = options()
            self.content = content()
        }

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    HeaderBar(info: info) { options }
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

    /// The page header on its own, above tables, which scroll by themselves.
    struct PageHeader<Options: View>: View {
        let info: Loc
        @ViewBuilder let options: Options

        init(_ info: Loc, @ViewBuilder options: () -> Options) {
            self.info = info
            self.options = options()
        }

        var body: some View {
            HeaderBar(info: info) { options }
                .padding(.horizontal, Space.page)
                .padding(.vertical, Space.row)
        }
    }

    /// A rounded surface with an optional heading above it.
    struct Card<Content: View>: View {
        let title: String?
        @ViewBuilder let content: Content

        init(_ title: String? = nil, @ViewBuilder _ content: () -> Content) {
            self.title = title
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: Space.s) {
                if let title { Text(title).textRole(.section).padding(.leading, Space.xs) }
                VStack(alignment: .leading, spacing: 0) { content }
                    .padding(.horizontal, Space.card)
                    .padding(.vertical, Space.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .surface()
            }
        }
    }

    /// Rows with a divider between them, the way grouped lists look on macOS.
    struct Rows<Data: RandomAccessCollection, Row: View>: View where Data.Element: Identifiable {
        let data: Data
        @ViewBuilder let row: (Data.Element) -> Row

        init(_ data: Data, @ViewBuilder _ row: @escaping (Data.Element) -> Row) {
            self.data = data
            self.row = row
        }

        var body: some View {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider() }
                row(item).padding(.vertical, Space.row)
            }
        }
    }
}

extension UI.Page where Options == EmptyView {
    init(_ pane: Pane, title: String? = nil, @ViewBuilder _ content: () -> Content) {
        self.init(pane, title: title, options: { EmptyView() }, content)
    }
}

/// The page's options on the left, a button explaining the page on the right.
private struct HeaderBar<Options: View>: View {
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
