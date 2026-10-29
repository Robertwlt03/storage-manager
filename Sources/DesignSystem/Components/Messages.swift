import SwiftUI

extension UI {
    /// One line that informs: an explanation, something in progress, or a result.
    struct Note: View {
        enum Style {
            case hint, working
            case good(symbol: String)
            case warning(symbol: String)
            case bad(symbol: String)
        }
        let text: String
        var style = Style.hint

        init(_ text: String, _ style: Style = .hint) {
            self.text = text
            self.style = style
        }

        var body: some View {
            switch style {
            case .hint:
                Text(text).textRole(.hint).fixedSize(horizontal: false, vertical: true)
            case .working:
                HStack(spacing: Space.small) {
                    ProgressView().controlSize(.small)
                    Text(text).foregroundStyle(.muted)
                }
            case .good(let symbol): result(symbol, .good)
            case .warning(let symbol): result(symbol, .warning)
            case .bad(let symbol): result(symbol, .bad)
            }
        }

        private func result(_ symbol: String, _ color: Color) -> some View {
            Label(text, systemImage: symbol).foregroundStyle(color)
                .contentTransition(.symbolEffect(.replace))
        }
    }

    /// Stands in for missing content: nothing found, nothing measured yet, or still being worked
    /// out.
    struct Placeholder: View {
        enum Kind {
            case empty(title: String, symbol: String, detail: String? = nil)
            case loading(title: TextKey, detail: TextKey, symbol: String)
            case notMeasured
            case emptyAfterScan(title: String, symbol: String, detail: String? = nil)
        }
        enum Placement { case inline, card, page }

        let kind: Kind
        var placement = Placement.inline
        @Environment(AppModel.self) private var model

        init(_ kind: Kind, in placement: Placement = .inline) {
            self.kind = kind
            self.placement = placement
        }

        var body: some View {
            switch placement {
            case .inline: content.frame(maxWidth: .infinity)
            case .card: content.frame(maxWidth: .infinity, minHeight: Layout.placeholderHeight)
            case .page:
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .containerRelativeFrame(.vertical, alignment: .center) { height, _ in
                        height * Layout.placeholderPageShare
                    }
            }
        }

        @ViewBuilder private var content: some View {
            switch kind {
            case .empty(let title, let symbol, let detail):
                Unavailable(title: title, symbol: symbol, detail: detail) { EmptyView() }
            case .loading(let title, let detail, let symbol):
                Unavailable(title: title.translated, symbol: symbol, detail: detail.translated) {
                    ProgressView().controlSize(.small)
                }
            case .notMeasured:
                notMeasured
            case .emptyAfterScan(let title, let symbol, let detail):
                if model.isScanning || !model.hasData {
                    notMeasured
                } else {
                    Unavailable(title: title, symbol: symbol, detail: detail) { EmptyView() }
                }
            }
        }

        private var notMeasured: some View {
            Unavailable(
                title: model.isScanning
                    ? TextKey.scanningTitle.translated : TextKey.notMeasuredTitle.translated,
                symbol: Symbols.measure,
                detail: model.isScanning
                    ? TextKey.scanningDetail.translated : TextKey.notMeasuredDetail.translated
            ) {
                if model.isScanning {
                    ProgressView().controlSize(.small)
                } else {
                    Button(TextKey.scanNow.translated) { model.scan() }.appButton(.primary)
                }
            }
        }
    }
}

/// The system's empty state with a darker description: its secondary colour stays below 4.5:1 in
/// light mode.
private struct Unavailable<Actions: View>: View {
    let title: String
    let symbol: String
    var detail: String?
    @ViewBuilder var actions: Actions

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol).foregroundStyle(.primary)
        } description: {
            if let detail { Text(detail).foregroundStyle(.muted) }
        } actions: {
            actions
        }
    }
}

extension View {
    /// A value still being calculated keeps its place but shows a small spinner, like
    /// "Calculating…" in Finder's Info window, and cannot be clicked, selected or read aloud until
    /// it is final.
    func calculating(_ isCalculating: Bool, alignment: Alignment = .leading) -> some View {
        opacity(isCalculating ? Opacity.hidden : Opacity.full)
            .overlay(alignment: alignment) {
                if isCalculating { ProgressView().controlSize(.small) }
            }
            .disabled(isCalculating)
            .accessibilityHidden(isCalculating)
    }
}
