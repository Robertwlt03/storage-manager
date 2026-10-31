import SwiftUI

/// All files from a chosen size, straight from the last scan.
struct LargeFilesView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.largeFileMegabytes) private var minimumMegabytes = LargeFileThreshold
        .defaultMegabytes

    /// Computed right away, so the table starts with its rows instead of diffing thousands in
    /// later.
    private var largeFiles: [Entry] {
        _ = model.revision
        let minimumBytes = LargeFileThreshold.bytes(minimumMegabytes)
        return SearchService.largeFiles(atLeast: minimumBytes, in: model.root)
    }

    var body: some View {
        let files = largeFiles
        let totalBytes = files.reduce(0) { total, file in total + file.bytes }
        EntryBrowser(
            entries: files, total: totalBytes, showsLocation: true, showsFileCount: false,
            emptyTitle: TextKey.noFilesFrom.translated(with: thresholdText(minimumMegabytes)),
            contentKey: "\(minimumMegabytes)"
        )
        .navigationTitle(TextKey.paneLargeFiles.translated)
        .navigationSubtitle(
            TextKey.filesTotal.translated(
                with: Format.count(files.count), Format.bytes(totalBytes))
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            UI.PageHeader(Pane.largeFiles.information) {
                LayoutSwitcher(pane: .largeFiles)
                minimumSizePicker
            }
        }
    }

    private var minimumSizePicker: some View {
        UI.MenuPicker(.minimumSize, selection: $minimumMegabytes) {
            ForEach(LargeFileThreshold.megabyteOptions, id: \.self) { megabytes in
                Text(TextKey.fromSize.translated(with: thresholdText(megabytes))).tag(megabytes)
            }
        }
    }

    private func thresholdText(_ megabytes: Int) -> String {
        Format.bytes(LargeFileThreshold.bytes(megabytes))
    }
}
