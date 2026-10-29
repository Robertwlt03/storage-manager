import SwiftUI

/// Removes caches, old logs and temporary files and empties the Trash, after a confirmation.
struct CleanerView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedKinds = Set(CleanKind.allCases.filter(\.isPreselected))
    @State private var isConfirming = false
    @State private var isCleaning = false
    @State private var result: (freed: Int64, failed: Int)?

    private var items: [CleanItem]? { model.cleanItems }
    /// Before the sizes are known, every kind is listed without a size.
    private var listedItems: [CleanItem] {
        items ?? CleanKind.allCases.map { kind in CleanItem(kind: kind, paths: [], bytes: 0) }
    }
    /// Sizes are still being found, or a scan is about to replace them.
    private var isLoading: Bool { items == nil || model.isScanning }
    private var chosenItems: [CleanItem] {
        (items ?? []).filter { item in selectedKinds.contains(item.kind) && item.bytes > 0 }
    }
    private var chosenBytes: Int64 { chosenItems.reduce(0) { total, item in total + item.bytes } }

    var body: some View {
        UI.Page(.cleaner, options: { refreshButton }, content)
            .task { if items == nil && !model.isScanning { model.refreshCleanItems() } }
            .confirmationDialog(
                TextKey.cleanConfirmTitle.translated(with: Format.bytes(chosenBytes)),
                isPresented: $isConfirming
            ) {
                Button(TextKey.deleteForever.translated, role: .destructive) {
                    Task { await clean() }
                }
                Button(TextKey.cancel.translated, role: .cancel) {}
            } message: {
                Text(TextKey.cleanConfirmMessage.translated)
            }
    }

    private var refreshButton: some View {
        UI.ActionButton(TextKey.cleanerRefresh.translated) { model.refreshCleanItems() }
            .disabled(isCleaning || isLoading)
    }

    @ViewBuilder private func content() -> some View {
        if !model.hasData && !model.isScanning {
            // Nothing to load: say so instead of spinning forever.
            UI.Placeholder(.notMeasured, in: .page)
        } else {
            UI.Card {
                UI.Rows(listedItems) { item in row(item) }
            }
        }
        if let result { resultNotes(result) }
        cleanBar
    }

    /// Only the checkbox is disabled for empty items, so their text stays readable.
    private func row(_ item: CleanItem) -> some View {
        HStack(spacing: Space.item) {
            Toggle(item.kind.title.translated, isOn: isSelected(item))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(item.bytes == 0 || isCleaning || isLoading)
            UI.Icon(
                .badge(symbol: item.kind.category.symbol, colorIndex: item.kind.category.rawValue))
            VStack(alignment: .leading, spacing: Space.hairline) {
                Text(item.kind.title.translated)
                Text(item.kind.detail.translated).textRole(.hint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Space.item)
            Text(item.bytes > 0 ? Format.bytes(item.bytes) : TextKey.emptyValue.translated)
                .textRole(.value)
                .calculating(isLoading, alignment: .trailing)
        }
    }

    private func isSelected(_ item: CleanItem) -> Binding<Bool> {
        Binding(
            get: { selectedKinds.contains(item.kind) && item.bytes > 0 },
            set: { isOn in
                if isOn { selectedKinds.insert(item.kind) } else { selectedKinds.remove(item.kind) }
            })
    }

    @ViewBuilder private func resultNotes(_ result: (freed: Int64, failed: Int)) -> some View {
        UI.Note(
            TextKey.freed.translated(with: Format.bytes(result.freed)),
            .good(symbol: Symbols.success))
        if result.failed > 0 {
            UI.Note(
                TextKey.cleanFailed.translated(with: Format.count(result.failed)),
                .warning(symbol: Symbols.warning))
        }
    }

    private var cleanBar: some View {
        HStack {
            if isCleaning { UI.Note(TextKey.cleaning.translated, .working) }
            Spacer()
            UI.ActionButton(
                TextKey.cleanSelected.translated(with: Format.bytes(chosenBytes)), .primary
            ) { isConfirming = true }
            .disabled(chosenItems.isEmpty || isCleaning || isLoading)
        }
    }

    private func clean() async {
        isCleaning = true
        result = await model.clean(chosenItems)
        isCleaning = false
    }
}
