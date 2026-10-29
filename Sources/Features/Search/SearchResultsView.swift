import SwiftUI

/// Results of the search field in the toolbar; replaces the page once something is typed.
/// The header holds the scope and Cancel, so the toolbar stays a single slim field.
struct SearchResultsView: View {
    @Environment(AppModel.self) private var model
    @State private var results: [Entry] = []
    @State private var resultsKey = ""  // query and scope the results belong to

    var body: some View {
        @Bindable var model = model
        EntryBrowser(entries: results, total: results.reduce(0) { $0 + $1.bytes }, showLocation: true,
                     emptyTitle: Loc.noResults.f(model.searchQuery),
                     emptyDetail: Loc.searchNote.s,
                     contentKey: resultsKey)
            .navigationTitle(Loc.searchResults.f(Fmt.count(results.count)))
            .safeAreaInset(edge: .top, spacing: 0) {
                UI.PageHeader(.searchNote) {
                    UI.SegmentPicker(selection: $model.searchScope) {
                        ForEach(SearchScope.allCases) { Text($0.title.s).tag($0) }
                    }
                    UI.ActionButton(Loc.cancel.s) { model.endSearch() }.keyboardShortcut(.cancelAction)
                }
            }
            .task(id: "\(model.searchText)|\(model.searchScope)|\(model.revision)") {
                try? await Task.sleep(for: ScanConfig.searchDebounce)  // wait until typing pauses
                guard !Task.isCancelled else { return }
                results = SearchService.search(model.searchText, scope: model.searchScope, in: model.root)
                resultsKey = "\(model.searchText)|\(model.searchScope)"
            }
    }
}
