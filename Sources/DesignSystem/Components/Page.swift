import SwiftUI

extension UI {
    /// A scrolling page: its header with options and information button, then the content.
    struct Page<Options: View, Content: View>: View {
        let title: String
        let information: TextKey
        @ViewBuilder let options: Options
        @ViewBuilder let content: Content

        init(
            _ pane: Pane, title: String? = nil, @ViewBuilder options: () -> Options,
            @ViewBuilder _ content: () -> Content
        ) {
            self.title = title ?? pane.title.translated
            information = pane.information
            self.options = options()
            self.content = content()
        }

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    HeaderBar(information: information) { options }
                    content
                }
                .padding(Space.page)
                .frame(maxWidth: Layout.maximumContentWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
            .background(Backdrop())
            .navigationTitle(title)
        }
    }

    /// The page header on its own, above tables, which scroll by themselves.
    struct PageHeader<Options: View>: View {
        let information: TextKey
        @ViewBuilder let options: Options

        init(_ information: TextKey, @ViewBuilder options: () -> Options) {
            self.information = information
            self.options = options()
        }

        var body: some View {
            HeaderBar(information: information) { options }
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
            VStack(alignment: .leading, spacing: Space.small) {
                if let title { Text(title).textRole(.section).padding(.leading, Space.extraSmall) }
                VStack(alignment: .leading, spacing: 0) { content }
                    .padding(.horizontal, Space.card)
                    .padding(.vertical, Space.small)
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
    let information: TextKey
    @ViewBuilder let options: Options
    @State private var isShowingInformation = false

    var body: some View {
        HStack(spacing: Space.item) {
            options
            Spacer(minLength: 0)
            informationButton
        }
        .frame(minHeight: Layout.headerHeight)
    }

    private var informationButton: some View {
        Button {
            isShowingInformation.toggle()
        } label: {
            Label(TextKey.aboutPage.translated, systemImage: Symbols.information)
        }
        .labelStyle(.iconOnly)
        .appButton(.quiet)
        .font(.title3)
        .help(TextKey.aboutPage.translated)
        .popover(isPresented: $isShowingInformation, arrowEdge: .bottom) { informationText }
    }

    private var informationText: some View {
        Text(information.translated)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Space.card)
            .frame(width: Layout.popoverWidth, alignment: .leading)
    }
}
