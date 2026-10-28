import SwiftUI

/// "In short": how the storage looks in a few sentences, with a button to hear it.
struct SummaryCard: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.unusedDays) private var unusedDays = CleanConfig.defaultUnusedDays
    private var speech: SpeechService { SpeechService.shared }

    var body: some View {
        let text = SummaryService.text(.init(
            volume: model.startupVolume, categories: model.scanning ? [] : model.categories,
            cleanable: model.cleanItems?.reduce(0) { $0 + $1.bytes }, copies: model.copyGroups.reduce(0) { $0 + $1.node.bytes },
            unusedApps: model.apps.filter { AppUsageService.isUnused($0, days: unusedDays) }.count))
        UI.card(Loc.summaryTitle.s) {
            VStack(alignment: .leading, spacing: Layout.rowSpacing) {
                Text(text).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                UI.button(speech.isSpeaking ? Loc.stopReading.s : Loc.readAloud.s) { speech.toggle(text) }
            }
            .padding(.vertical, Layout.rowPadding)
        }
    }
}
