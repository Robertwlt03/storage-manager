import SwiftUI

/// All files from a chosen size, straight from the last scan.
struct LargeFilesView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.largeFileMB) private var minMB = LargeFileThreshold.defaultMB
    var body: some View {
        // Computed right away, so the table starts with its rows instead of diffing thousands in later.
        let _ = model.revision
        let entries = SearchService.largeFiles(
            atLeast: LargeFileThreshold.bytes(minMB), in: model.root)
        let sum = entries.reduce(0) { $0 + $1.bytes }
        EntryBrowser(
            entries: entries, total: sum, showLocation: true,
            emptyTitle: TextKey.noFilesFrom.translated(with: threshold(minMB)),
            contentKey: "\(minMB)"
        )
        .navigationTitle(TextKey.paneLargeFiles.translated)
        .navigationSubtitle(
            TextKey.filesTotal.translated(with: Format.count(entries.count), Format.bytes(sum))
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            UI.PageHeader(Pane.largeFiles.info) {
                UI.MenuPicker(.minimumSize, selection: $minMB) {
                    ForEach(LargeFileThreshold.optionsMB, id: \.self) {
                        Text(TextKey.fromSize.translated(with: threshold($0))).tag($0)
                    }
                }
            }
        }
    }

    private func threshold(_ mb: Int) -> String { Format.bytes(LargeFileThreshold.bytes(mb)) }
}
