import AppKit
import SwiftUI

/// Shown once at launch without Full Disk Access: one switch in System Settings instead of many single prompts.
struct AccessSheet: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.accessPromptDismissed) private var dontAsk = false
    @State private var visitedSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            UI.header(Loc.accessTitle.s, subtitle: Loc.accessOneSwitch.s, icon: .file(Bundle.main.bundlePath))
            UI.note(Loc.accessDetail.s)
            if visitedSettings { UI.status(Loc.accessRestartHint.s, symbol: Symbols.warning, .warn) }
            Toggle(Loc.accessDontAsk.s, isOn: $dontAsk)
            HStack {
                UI.button(Loc.accessContinue.s) { model.finishAccessSheet() }
                Spacer()
                if visitedSettings { UI.button(Loc.accessRestart.s) { LifecycleService.relaunch() } }
                UI.button(Loc.accessOpenSettings.s, prominent: !visitedSettings) {
                    visitedSettings = true
                    FinderService.openFullDiskAccessSettings()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Layout.pagePadding)
        .frame(width: Layout.sheetWidth)
        // Back from System Settings: close if access works already, otherwise the hint above explains the restart.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshAccess()
            if model.hasFullDiskAccess { model.finishAccessSheet() }
        }
    }
}
