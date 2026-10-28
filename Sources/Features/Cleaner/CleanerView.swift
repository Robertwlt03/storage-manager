import SwiftUI

/// Removes caches, old logs and temporary files and empties the Trash, after a confirmation.
struct CleanerView: View {
    @Environment(AppModel.self) private var model
    @State private var selected = Set(CleanKind.allCases.filter(\.preselected))
    @State private var confirming = false
    @State private var cleaning = false
    @State private var result: (freed: Int64, failed: Int)?

    private var items: [CleanItem]? { model.cleanItems }
    private var chosen: [CleanItem] { (items ?? []).filter { selected.contains($0.kind) && $0.bytes > 0 } }
    private var chosenBytes: Int64 { chosen.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        UI.page(.cleaner, options: {
            UI.button(Loc.cleanerRefresh.s) { model.refreshCleanItems() }.disabled(cleaning || items == nil)
        }) {
            UI.card {
                if let items {
                    UI.rows(items) { item in row(item) }
                } else {
                    UI.progress(Loc.cleanerSearching.s).padding(.vertical, Layout.rowPadding)
                }
            }
            if let result {
                UI.status(Loc.freed.f(Fmt.bytes(result.freed)), symbol: Symbols.success, .good)
                if result.failed > 0 { UI.status(Loc.cleanFailed.f(Fmt.count(result.failed)), symbol: Symbols.warning, .warn) }
            }
            HStack {
                if cleaning { UI.progress(Loc.cleaning.s) }
                Spacer()
                UI.button(Loc.cleanSelected.f(Fmt.bytes(chosenBytes)), .primary) { confirming = true }
                    .disabled(chosen.isEmpty || cleaning)
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
        HStack(spacing: Layout.rowSpacing) {
            Toggle(item.kind.title.s, isOn: Binding(get: { selected.contains(item.kind) && item.bytes > 0 },
                                                    set: { on in if on { selected.insert(item.kind) } else { selected.remove(item.kind) } }))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(item.bytes == 0 || cleaning)
            RowIconView(icon: .badge(symbol: item.kind.category.symbol, colorIndex: item.kind.category.rawValue))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.kind.title.s)
                Text(item.kind.detail.s).font(.callout).foregroundStyle(.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Layout.rowSpacing)
            Text(item.bytes > 0 ? Fmt.bytes(item.bytes) : Loc.emptyValue.s).monospacedDigit().foregroundStyle(.muted)
        }
    }

    private func clean() async {
        cleaning = true
        result = await model.clean(chosen)
        cleaning = false
    }
}
