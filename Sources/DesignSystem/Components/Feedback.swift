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
        HStack(spacing: 8) {
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

/// Shown at the top of every page while a scan runs: how far it is, which area, and a way to stop.
struct ScanBanner: View {
    var inset = false  // true when it floats above a table instead of sitting inside a page
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: Layout.rowSpacing) {
                Text(Loc.scanningPercent.f(Fmt.percent(model.scanFraction))).font(.headline).monospacedDigit()
                Text(Loc.scanningArea.f(Fmt.count(model.scanStep.index), Fmt.count(model.scanStep.count), Paths.display(model.scanStep.path)))
                    .foregroundStyle(.muted).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: Layout.rowSpacing)
                Button(Loc.cancel.s) { model.cancelScan() }.appButton()
            }
            ProgressView(value: model.scanFraction).progressViewStyle(.linear)
            Text(Loc.filesAndSize.f(Fmt.count(model.progress.files), Fmt.bytes(model.progress.bytes)))
                .font(.callout).foregroundStyle(.muted).monospacedDigit()
        }
        .padding(Layout.cardPadding)
        .surface()
        .padding(.horizontal, inset ? Layout.pagePadding : 0)
        .padding(.top, inset ? Layout.rowPadding : 0)
        .accessibilityElement(children: .combine)
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
