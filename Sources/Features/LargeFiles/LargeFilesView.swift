import SwiftUI

/// All files from a chosen size, straight from the last scan.
struct LargeFilesView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.largeFileMB) private var minMB = LargeFileThreshold.defaultMB
    @State private var entries: [Entry] = []

    var body: some View {
        let sum = entries.reduce(0) { $0 + $1.bytes }
        EntryBrowser(entries: entries, total: sum, showLocation: true, emptyTitle: Loc.noFilesFrom.f(threshold(minMB)))
            .navigationTitle(Loc.paneLargeFiles.s)
            .navigationSubtitle(Loc.filesTotal.f(Fmt.count(entries.count), Fmt.bytes(sum)))
            .safeAreaInset(edge: .top, spacing: 0) {
                UI.header(Pane.largeFiles.info) {
                    UI.menu(.minSize, selection: $minMB) {
                        ForEach(LargeFileThreshold.optionsMB, id: \.self) { Text(Loc.fromSize.f(threshold($0))).tag($0) }
                    }
                }
            }
            .task(id: "\(minMB)-\(model.revision)") {
                entries = SearchService.largeFiles(atLeast: LargeFileThreshold.bytes(minMB), in: model.root)
            }
    }

    private func threshold(_ mb: Int) -> String { Fmt.bytes(LargeFileThreshold.bytes(mb)) }
}
