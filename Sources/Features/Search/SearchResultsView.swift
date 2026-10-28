import SwiftUI

/// Results of the search field in the toolbar; replaces the page while the field is active.
/// The header always offers Cancel, so the search can be left without typing or clicking elsewhere.
struct SearchResultsView: View {
    @Environment(AppModel.self) private var model
    @State private var results: [Entry] = []
    @State private var resultsKey = ""  // query and scope the results belong to

    var body: some View {
        EntryBrowser(entries: results, total: results.reduce(0) { $0 + $1.bytes }, showLocation: true,
                     emptyTitle: model.searchQuery.isEmpty ? Loc.searchPrompt.s : Loc.noResults.f(model.searchQuery),
                     emptyDetail: Loc.searchNote.s,
                     contentKey: resultsKey)
            .navigationTitle(Loc.searchResults.f(Fmt.count(results.count)))
            .safeAreaInset(edge: .top, spacing: 0) {
                UI.header(.searchNote) {
                    UI.button(Loc.cancel.s) { model.endSearch() }.keyboardShortcut(.cancelAction)
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
