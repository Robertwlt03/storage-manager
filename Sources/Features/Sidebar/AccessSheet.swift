import AppKit
import SwiftUI

/// Shown at every launch until Full Disk Access works: one switch in System Settings instead of many single prompts.
struct AccessSheet: View {
    @Environment(AppModel.self) private var model
    @State private var visitedSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.section) {
            UI.header(Loc.accessTitle.s, subtitle: Loc.accessOneSwitch.s, icon: .file(Bundle.main.bundlePath))
            UI.note(Loc.accessDetail.s)
            if visitedSettings { UI.status(Loc.accessRestartHint.s, symbol: Symbols.warning, .warn) }
            HStack {
                UI.button(Loc.accessContinue.s) { model.finishAccessSheet() }
                Spacer()
                UI.button(Loc.accessOpenSettings.s, .primary) {
                    visitedSettings = true
                    FinderService.openFullDiskAccessSettings()
                }
                .keyboardShortcut(visitedSettings ? nil : .defaultAction)
                if visitedSettings {
                    UI.button(Loc.accessRestart.s, .confirm) { LifecycleService.relaunch() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(Space.page)
        .frame(width: Layout.sheetWidth)
        // Back from System Settings: close if access works already, otherwise the hint above explains the restart.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshAccess()
            if model.hasFullDiskAccess { model.finishAccessSheet() }
        }
    }
}
