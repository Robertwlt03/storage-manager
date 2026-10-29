import SwiftUI

/// Results of the search field in the toolbar; replaces the page once something is typed.
/// The header holds the scope and Cancel, so the toolbar stays a single slim field.
struct SearchResultsView: View {
    @Environment(AppModel.self) private var model
    @State private var results: [Entry] = []
    @State private var resultsKey = ""  // query and scope the results belong to

    /// The query and scope as they are now.
    private var searchKey: String { "\(model.searchText)|\(model.searchScope)" }

    var body: some View {
        @Bindable var model = model
        EntryBrowser(
            entries: results,
            total: results.reduce(0) { total, result in total + result.bytes },
            showLocation: true,
            emptyTitle: TextKey.noResults.translated(with: model.searchQuery),
            emptyDetail: TextKey.searchNote.translated,
            contentKey: resultsKey
        )
        .navigationTitle(TextKey.searchResults.translated(with: Format.count(results.count)))
        .safeAreaInset(edge: .top, spacing: 0) {
            UI.PageHeader(.searchNote) {
                UI.SegmentPicker(selection: $model.searchScope) {
                    ForEach(SearchScope.allCases) { scope in
                        Text(scope.title.translated).tag(scope)
                    }
                }
                UI.ActionButton(TextKey.cancel.translated) { model.endSearch() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .task(id: "\(searchKey)|\(model.revision)") { await searchOnceTypingPauses() }
    }

    private func searchOnceTypingPauses() async {
        try? await Task.sleep(for: ScanConfig.searchDebounce)
        guard !Task.isCancelled else { return }
        results = SearchService.search(model.searchText, scope: model.searchScope, in: model.root)
        resultsKey = searchKey
    }
}
