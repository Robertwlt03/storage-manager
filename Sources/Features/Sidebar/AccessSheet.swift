import AppKit
import SwiftUI

/// Shown once at launch without Full Disk Access: one switch in System Settings instead of many single prompts.
struct AccessSheet: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.accessPromptDismissed) private var dontAsk = false

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            UI.header(Loc.accessTitle.s, subtitle: Loc.accessOneSwitch.s, icon: .file(Bundle.main.bundlePath))
            UI.note(Loc.accessDetail.s)
            Toggle(Loc.accessDontAsk.s, isOn: $dontAsk)
            HStack {
                UI.button(Loc.accessContinue.s) { model.finishAccessSheet() }
                Spacer()
                UI.button(Loc.accessOpenSettings.s, prominent: true) { FinderService.openFullDiskAccessSettings() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Layout.pagePadding)
        .frame(width: Layout.sheetWidth)
        // Back from System Settings: if access was granted, close and start measuring.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshAccess()
            if model.hasFullDiskAccess { model.finishAccessSheet() }
        }
    }
}
