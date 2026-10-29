import SwiftUI

/// "In short": the storage in a few sentences, read aloud on request; both wait until the scan is done.
struct SummaryCard: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.unusedDays) private var unusedDays = CleanConfig.defaultUnusedDays
    private var speech: SpeechService { SpeechService.shared }

    var body: some View {
        let text = SummaryService.text(.init(
            volume: model.startupVolume, categories: model.scanning ? [] : model.categories,
            cleanable: model.cleanItems?.reduce(0) { $0 + $1.bytes }, copies: model.copyGroups.reduce(0) { $0 + $1.node.bytes },
            unusedApps: model.apps.filter { AppUsageService.isUnused($0, days: unusedDays) }.count))
        let loading = model.scanning
        UI.Card(Loc.summaryTitle.s) {
            VStack(alignment: .leading, spacing: Space.item) {
                if loading {
                    UI.Placeholder(.loading(title: .loadingSummaryTitle, detail: .loadingSummaryDetail, symbol: Symbols.summary))
                } else {
                    Text(text).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
                Button { speech.toggle(text) } label: {
                    Label(speech.isSpeaking ? Loc.stopReading.s : Loc.readAloud.s, systemImage: Symbols.speaker)
                        .symbolEffect(.variableColor.iterative, isActive: speech.isSpeaking)  // only while speaking
                }
                .appButton()
                .disabled(loading)
            }
            .padding(.vertical, Space.row)
        }
    }
}
