import SwiftUI

/// The answer the overview starts with: how much space can be freed, then the steps to it in the
/// order to take them, each with a button to its page. Duplicates count only once their page has
/// searched them, because the overview reads no files.
struct FreeUpCard: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.unusedDays) private var unusedDays = CleanUpRules.defaultUnusedDays

    var body: some View {
        UI.Card {
            if model.isScanning || !model.hasData {
                UI.Placeholder(.notMeasured).padding(.vertical, Space.row)
            } else if let cleanableBytes = model.cleanableBytes {
                guide(cleanableBytes: cleanableBytes)
            } else {
                UI.Placeholder(
                    .loading(
                        title: .freeUpLoadingTitle, detail: .freeUpLoadingDetail,
                        symbol: Symbols.cleaner)
                )
                .padding(.vertical, Space.row)
            }
        }
    }

    @ViewBuilder private func guide(cleanableBytes: Int64) -> some View {
        let unusedApps = AppUsageService.unused(model.apps, days: unusedDays)
        let steps = FreeUpService.steps(
            cleanableBytes: cleanableBytes, duplicateBytes: model.duplicateSpareBytes,
            unusedApps: unusedApps)
        headline(steps)
        UI.Rows(steps) { step in
            row(
                step, detail: detail(of: step, unusedAppCount: unusedApps.count),
                button: step.id == steps.first?.id ? .primary : .normal)
        }
    }

    /// The good news only once no step is left; otherwise the total of what is known so far, and
    /// only the hint while no step has a size yet.
    @ViewBuilder private func headline(_ steps: [FreeUpService.Step]) -> some View {
        if steps.isEmpty {
            UI.Note(TextKey.freeUpNothing.translated, .good(symbol: Symbols.success))
                .padding(.vertical, Space.row)
        } else {
            total(FreeUpService.total(steps)).padding(.vertical, Space.row)
        }
    }

    private func total(_ bytesToFree: Int64) -> some View {
        VStack(alignment: .leading, spacing: Space.extraSmall) {
            if bytesToFree > 0 {
                Text(TextKey.freeUpTitle.translated(with: Format.bytes(bytesToFree)))
                    .textRole(.title).accessibilityAddTraits(.isHeader)
            }
            UI.Note(TextKey.freeUpCaption.translated)
        }
    }

    private func detail(of step: FreeUpService.Step, unusedAppCount: Int) -> String {
        switch step.pane {
        case .cleaner: TextKey.freeUpCleanerDetail.translated
        case .duplicates:
            step.bytes == nil
                ? TextKey.freeUpDuplicatesNotSearched.translated
                : TextKey.freeUpDuplicatesDetail.translated
        default: TextKey.freeUpAppsDetail.translated(with: Format.count(unusedAppCount))
        }
    }

    /// Every button reads the same, so they are equally wide; the first step is the one to take
    /// next.
    private func row(_ step: FreeUpService.Step, detail: String, button: ButtonKind) -> some View {
        HStack(spacing: Space.item) {
            UI.Icon(.accent(step.pane.symbol))
            VStack(alignment: .leading, spacing: Space.hairline) {
                Text(step.pane.title.translated)
                Text(detail).textRole(.hint)
            }
            Spacer(minLength: Space.item)
            if let bytes = step.bytes { Text(Format.bytes(bytes)).textRole(.value) }
            // Named after its step, so VoiceOver tells the buttons apart; "Open" still works for
            // Voice Control.
            UI.ActionButton(TextKey.open.translated, button) { model.pane = step.pane }
                .accessibilityLabel(step.pane.title.translated)
                .accessibilityInputLabels([TextKey.open.translated, step.pane.title.translated])
        }
        .accessibilityElement(children: .contain)
    }
}
