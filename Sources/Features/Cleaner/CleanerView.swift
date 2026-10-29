import SwiftUI

/// Removes caches, old logs and temporary files and empties the Trash, after a confirmation.
struct CleanerView: View {
    @Environment(AppModel.self) private var model
    @State private var selected = Set(CleanKind.allCases.filter(\.preselected))
    @State private var confirming = false
    @State private var cleaning = false
    @State private var result: (freed: Int64, failed: Int)?

    private var items: [CleanItem]? { model.cleanItems }
    /// Sizes are still being found, or a scan is about to replace them.
    private var loading: Bool { items == nil || model.scanning }
    private var chosen: [CleanItem] { (items ?? []).filter { selected.contains($0.kind) && $0.bytes > 0 } }
    private var chosenBytes: Int64 { chosen.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        UI.Page(.cleaner, options: {
            UI.ActionButton(Loc.cleanerRefresh.s) { model.refreshCleanItems() }.disabled(cleaning || loading)
        }) {
            if !model.hasData && !model.scanning {  // nothing to load: say so instead of spinning forever
                UI.Placeholder(.notMeasured, in: .page)
            } else {
                UI.Card {
                    UI.Rows(items ?? CleanKind.allCases.map { CleanItem(kind: $0, paths: [], bytes: 0) }) { item in row(item) }
                }
            }
            if let result {
                UI.Note(Loc.freed.f(Fmt.bytes(result.freed)), .good(symbol: Symbols.success))
                if result.failed > 0 { UI.Note(Loc.cleanFailed.f(Fmt.count(result.failed)), .warn(symbol: Symbols.warning)) }
            }
            HStack {
                if cleaning { UI.Note(Loc.cleaning.s, .working) }
                Spacer()
                UI.ActionButton(Loc.cleanSelected.f(Fmt.bytes(chosenBytes)), .primary) { confirming = true }
                    .disabled(chosen.isEmpty || cleaning || loading)
            }
        }
        .task { if items == nil && !model.scanning { model.refreshCleanItems() } }
        .confirmationDialog(Loc.cleanConfirmTitle.f(Fmt.bytes(chosenBytes)), isPresented: $confirming) {
            Button(Loc.deleteForever.s, role: .destructive) { Task { await clean() } }
            Button(Loc.cancel.s, role: .cancel) {}
        } message: {
            Text(Loc.cleanConfirmMessage.s)
        }
    }

    /// Only the checkbox is disabled for empty items, so their text stays readable.
    private func row(_ item: CleanItem) -> some View {
        HStack(spacing: Space.item) {
            Toggle(item.kind.title.s, isOn: Binding(get: { selected.contains(item.kind) && item.bytes > 0 },
                                                    set: { on in if on { selected.insert(item.kind) } else { selected.remove(item.kind) } }))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(item.bytes == 0 || cleaning || loading)
            UI.Icon(.badge(symbol: item.kind.category.symbol, colorIndex: item.kind.category.rawValue))
            VStack(alignment: .leading, spacing: Space.hairline) {
                Text(item.kind.title.s)
                Text(item.kind.detail.s).textRole(.hint).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Space.item)
            Text(item.bytes > 0 ? Fmt.bytes(item.bytes) : Loc.emptyValue.s).textRole(.value)
                .calculating(loading, alignment: .trailing)
        }
    }

    private func clean() async {
        cleaning = true
        result = await model.clean(chosen)
        cleaning = false
    }
}
