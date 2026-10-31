import AppKit
import SwiftUI

/// Shown at every launch until Full Disk Access works: one switch in System Settings instead of
/// many single prompts.
struct AccessSheet: View {
    @Environment(AppModel.self) private var model
    @State private var hasVisitedSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.section) {
            UI.TitleRow(
                TextKey.accessTitle.translated, subtitle: TextKey.accessOneSwitch.translated,
                icon: .file(Bundle.main.bundlePath))
            UI.Note(TextKey.accessDetail.translated)
            if hasVisitedSettings {
                UI.Note(TextKey.accessRestartHint.translated, .warning(symbol: Symbols.warning))
            }
            buttons
        }
        .padding(Space.page)
        .frame(width: Layout.sheetWidth)
        // Back from System Settings: close if access works already, otherwise the hint above
        // explains the restart.
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            model.refreshAccess()
            if model.hasFullDiskAccess { model.finishAccessSheet() }
        }
    }

    private var buttons: some View {
        HStack {
            UI.ActionButton(TextKey.accessContinue.translated) { model.finishAccessSheet() }
            Spacer()
            // Once System Settings were visited, the restart is the one prominent step left.
            UI.ActionButton(
                TextKey.accessOpenSettings.translated, hasVisitedSettings ? .normal : .primary
            ) {
                hasVisitedSettings = true
                FinderService.openFullDiskAccessSettings()
            }
            .keyboardShortcut(hasVisitedSettings ? nil : .defaultAction)
            if hasVisitedSettings { restartButton }
        }
    }

    private var restartButton: some View {
        UI.ActionButton(TextKey.accessRestart.translated, .primary) {
            LifecycleService.relaunch()
        }
        .keyboardShortcut(.defaultAction)
    }
}
