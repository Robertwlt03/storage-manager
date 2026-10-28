import SwiftUI

/// Results of the search field in the toolbar; replaces the page while a term is entered.
struct SearchResultsView: View {
    @Environment(AppModel.self) private var model
    @State private var results: [Entry] = []

    var body: some View {
        EntryBrowser(entries: results, total: results.reduce(0) { $0 + $1.bytes }, showLocation: true,
                     emptyTitle: Loc.noResults.f(model.searchText), emptyDetail: Loc.searchNote.s)
            .navigationTitle(Loc.searchResults.f(Fmt.count(results.count)))
            .task(id: "\(model.searchText)|\(model.searchScope)|\(model.revision)") {
                try? await Task.sleep(for: ScanConfig.searchDebounce)  // wait until typing pauses
                guard !Task.isCancelled else { return }
                results = SearchService.search(model.searchText, scope: model.searchScope, in: model.root)
            }
    }
}
