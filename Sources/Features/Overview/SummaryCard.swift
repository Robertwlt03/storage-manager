import SwiftUI

/// "In short": the storage in a few sentences, read aloud on request; both wait until the scan is
/// done.
struct SummaryCard: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.unusedDays) private var unusedDays = CleanUpRules.defaultUnusedDays
    private var speech: SpeechService { SpeechService.shared }

    private var summary: String {
        let cleanableBytes = model.cleanItems?.reduce(0) { total, item in total + item.bytes }
        let copiesBytes = model.copyGroups.reduce(0) { total, group in total + group.node.bytes }
        let unusedApps = AppUsageService.unused(model.apps, days: unusedDays)
        let facts = SummaryService.Input(
            volume: model.startupVolume, categories: model.isScanning ? [] : model.categories,
            cleanable: cleanableBytes, copies: copiesBytes, unusedApps: unusedApps.count)
        return SummaryService.text(facts)
    }

    var body: some View {
        let summary = summary
        let isLoading = model.isScanning
        UI.Card(TextKey.summaryTitle.translated) {
            VStack(alignment: .leading, spacing: Space.item) {
                if isLoading {
                    UI.Placeholder(
                        .loading(
                            title: .loadingSummaryTitle, detail: .loadingSummaryDetail,
                            symbol: Symbols.summary))
                } else {
                    Text(summary).fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                readAloudButton(summary).disabled(isLoading)
            }
            .padding(.vertical, Space.row)
        }
    }

    private func readAloudButton(_ summary: String) -> some View {
        Button {
            speech.toggle(summary)
        } label: {
            Label(
                speech.isSpeaking ? TextKey.stopReading.translated : TextKey.readAloud.translated,
                systemImage: Symbols.speaker
            )
            .symbolEffect(.variableColor.iterative, isActive: speech.isSpeaking)
        }
        .appButton()
    }
}
