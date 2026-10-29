import SwiftUI

/// All files from a chosen size, straight from the last scan.
struct LargeFilesView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.largeFileMB) private var minMB = LargeFileThreshold.defaultMB
    var body: some View {
        // Computed right away (a quick walk over the tree), so the table is created with its rows instead of
        // starting empty and being diffed into thousands of rows a moment later.
        let _ = model.revision
        let entries = SearchService.largeFiles(atLeast: LargeFileThreshold.bytes(minMB), in: model.root)
        let sum = entries.reduce(0) { $0 + $1.bytes }
        EntryBrowser(entries: entries, total: sum, showLocation: true, emptyTitle: Loc.noFilesFrom.f(threshold(minMB)),
                     contentKey: "\(minMB)")
            .navigationTitle(Loc.paneLargeFiles.s)
            .navigationSubtitle(Loc.filesTotal.f(Fmt.count(entries.count), Fmt.bytes(sum)))
            .safeAreaInset(edge: .top, spacing: 0) {
                UI.PageHeader(Pane.largeFiles.info) {
                    UI.MenuPicker(.minSize, selection: $minMB) {
                        ForEach(LargeFileThreshold.optionsMB, id: \.self) { Text(Loc.fromSize.f(threshold($0))).tag($0) }
                    }
                }
            }
    }

    private func threshold(_ mb: Int) -> String { Fmt.bytes(LargeFileThreshold.bytes(mb)) }
}
