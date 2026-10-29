import SwiftUI

/// All files from a chosen size, straight from the last scan.
struct LargeFilesView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.largeFileMB) private var minMB = LargeFileThreshold.defaultMB
    var body: some View {
        // Computed right away, so the table starts with its rows instead of diffing thousands in later.
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
