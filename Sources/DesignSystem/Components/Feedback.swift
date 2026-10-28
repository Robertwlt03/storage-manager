import SwiftUI

/// A short explanation in the muted tone.
struct Note: View {
    let text: String

    var body: some View {
        Text(text).font(.callout).foregroundStyle(.muted).fixedSize(horizontal: false, vertical: true)
    }
}

/// Small spinner with a text.
struct ProgressLine: View {
    let text: String

    var body: some View {
        HStack(spacing: Space.s) {
            ProgressView().controlSize(.small)
            Text(text).foregroundStyle(.muted)
        }
    }
}

/// Coloured status label (running, freed, error).
struct StatusLabel: View {
    enum Kind { case good, warn, bad }
    let text: String
    let symbol: String
    let kind: Kind

    var body: some View {
        Label(text, systemImage: symbol).foregroundStyle(kind == .good ? .good : kind == .warn ? .warn : .bad)
    }
}

/// Empty state with a muted description (the system's secondary colour is too faint in light mode).
struct EmptyState<Actions: View>: View {
    let title: String
    let symbol: String
    var detail: String?
    @ViewBuilder var actions: Actions

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol).foregroundStyle(.primary)  // the default is too faint in light mode
        } description: {
            if let detail { Text(detail).foregroundStyle(.muted) }
        } actions: {
            actions
        }
    }
}

/// Shown on every page while nothing has been measured yet.
struct NotMeasured: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        EmptyState(title: model.scanning ? Loc.scanningTitle.s : Loc.notMeasuredTitle.s, symbol: Symbols.measure,
                   detail: model.scanning ? Loc.scanningDetail.s : Loc.notMeasuredDetail.s) {
            if model.scanning { ProgressView().controlSize(.small) } else {
                Button(Loc.scanNow.s) { model.scan() }.appButton(.primary)
            }
        }
    }
}

/// Empty result: while scanning it says so, otherwise it shows the given empty state.
struct EmptyOrScanning: View {
    let title: String
    let symbol: String
    var detail: String?
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.scanning || !model.hasData { NotMeasured() } else { EmptyState(title: title, symbol: symbol, detail: detail) { EmptyView() } }
    }
}

/// Stands in for a chart that is still being calculated: the same height with a small spinner, so nothing moves.
struct PendingBlock: View {
    let height: CGFloat

    var body: some View {
        ProgressView().controlSize(.small).frame(maxWidth: .infinity, minHeight: height)
    }
}

extension View {
    /// While a value is still being calculated it keeps its place but shows a small spinner instead, like
    /// "Calculating…" in Finder's Info window, and cannot be clicked, selected or read aloud in a state that is
    /// about to change. The spinner only runs as long as the calculation does.
    func calculating(_ active: Bool, alignment: Alignment = .leading) -> some View {
        opacity(active ? 0 : 1)
            .overlay(alignment: alignment) { if active { ProgressView().controlSize(.small) } }
            .disabled(active)
            .accessibilityHidden(active)
    }
}
