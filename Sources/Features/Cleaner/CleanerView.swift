import SwiftUI

/// Removes caches, old logs and temporary files and empties the Trash, after a confirmation.
struct CleanerView: View {
    @Environment(AppModel.self) private var model
    @State private var items: [CleanItem]?
    @State private var selected = Set(CleanKind.allCases.filter(\.preselected))
    @State private var confirming = false
    @State private var cleaning = false
    @State private var result: (freed: Int64, failed: Int)?

    private var chosen: [CleanItem] { (items ?? []).filter { selected.contains($0.kind) && $0.bytes > 0 } }
    private var chosenBytes: Int64 { chosen.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        UI.page(Loc.paneCleaner.s) {
            UI.note(Loc.cleanerIntro.s)
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
                UI.button(Loc.cleanerRefresh.s) { Task { await load() } }.disabled(cleaning)
                UI.button(Loc.cleanSelected.f(Fmt.bytes(chosenBytes)), .primary) { confirming = true }
                    .disabled(chosen.isEmpty || cleaning)
            }
        }
        .task { await load() }
        .confirmationDialog(Loc.cleanConfirmTitle.f(Fmt.bytes(chosenBytes)), isPresented: $confirming) {
            Button(Loc.deleteForever.s, role: .destructive) { Task { await clean() } }
            Button(Loc.cancel.s, role: .cancel) {}
        } message: {
            Text(Loc.cleanConfirmMessage.s)
        }
    }

    private func row(_ item: CleanItem) -> some View {
        Toggle(isOn: Binding(get: { selected.contains(item.kind) },
                             set: { on in if on { selected.insert(item.kind) } else { selected.remove(item.kind) } })) {
            HStack(spacing: Layout.rowSpacing) {
                RowIconView(icon: .badge(symbol: item.kind.category.symbol, colorIndex: item.kind.category.rawValue))
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.kind.title.s)
                    Text(item.kind.detail.s).font(.callout).foregroundStyle(.muted)
                }
                Spacer(minLength: Layout.rowSpacing)
                Text(Fmt.bytes(item.bytes)).monospacedDigit().foregroundStyle(.muted)
            }
        }
        .toggleStyle(.checkbox)
        .disabled(item.bytes == 0 || cleaning)
    }

    private func load() async {
        items = nil
        items = await Task.detached(priority: .utility) { CleanerService.candidates() }.value
    }

    private func clean() async {
        cleaning = true
        result = await model.clean(chosen)
        cleaning = false
        await load()
    }
}
