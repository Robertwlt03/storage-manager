import SwiftUI

/// "In short": the storage in a few sentences, read aloud on request; both wait until the scan is
/// done.
struct SummaryCard: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.unusedDays) private var unusedDays = CleanUpRules.defaultUnusedDays
    private var speech: SpeechService { SpeechService.shared }

    private var summary: String { model.summary(unusedDays: unusedDays) }

    var body: some View {
        let summary = summary
        let isLoading = model.isScanning
        UI.Card(TextKey.summaryTitle.translated) {
            VStack(alignment: .leading, spacing: Space.item) {
                summaryText(summary, isLoading: isLoading)
                if speech.canSpeak { readAloudButton(summary).disabled(isLoading) }
            }
            .padding(.vertical, Space.row)
        }
    }

    @ViewBuilder private func summaryText(_ summary: String, isLoading: Bool) -> some View {
        if isLoading {
            UI.Placeholder(
                .loading(
                    title: .loadingSummaryTitle, detail: .loadingSummaryDetail,
                    symbol: Symbols.summary))
        } else {
            Text(summary).fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private func readAloudButton(_ summary: String) -> some View {
        UI.ActionButton(
            speech.isSpeaking ? TextKey.stopReading.translated : TextKey.readAloud.translated,
            .inline
        ) { speech.toggle(summary) }
    }
}
