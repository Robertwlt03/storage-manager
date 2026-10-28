import AppKit
import SwiftUI

@main
enum AppEntry {
    @MainActor static func main() {
        AppSettings.registerDefaults()
        let args = CommandLine.arguments
        if args.contains(LaunchCommand.checkContrast.rawValue) { exit(Checks.contrast() ? 0 : 1) }
        if args.contains(LaunchCommand.checkStrings.rawValue) { exit(Checks.strings() ? 0 : 1) }
        if args.contains(LaunchCommand.selfTest.rawValue) {
            Task.detached { SelfTest.run(); exit(0) }
            dispatchMain()
        }
        if let i = args.firstIndex(of: LaunchCommand.renderIcon.rawValue), i + 1 < args.count {
            exit(Checks.renderIcon(to: args[i + 1]) ? 0 : 1)
        }
        SpeicherExplorerApp.main()
    }
}

struct SpeicherExplorerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window(Loc.appName.s, id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: Layout.minWindowWidth, minHeight: Layout.minWindowHeight)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button(Loc.rescan.s) { model.scan() }.keyboardShortcut("r").disabled(model.scanning)
                Button(Loc.cancelScan.s) { model.cancelScan() }.keyboardShortcut(".").disabled(!model.scanning)
            }
        }
        Settings {
            SettingsView().environment(model)
        }
    }
}

/// Gives every window the app's locale for dates and numbers; used by every window so none can forget it.
private struct PreferenceSync: ViewModifier {
    func body(content: Content) -> some View { content.environment(\.locale, Localizer.shared.locale) }
}

extension View {
    func syncPreferences() -> some View { modifier(PreferenceSync()) }
}
