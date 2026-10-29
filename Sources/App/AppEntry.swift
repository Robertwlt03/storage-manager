import AppKit
import SwiftUI

@main
enum AppEntry {
    @MainActor static func main() {
        AppSettings.registerDefaults()
        let arguments = CommandLine.arguments
        if arguments.contains(LaunchCommand.checkContrast.rawValue) {
            finish(succeeded: Checks.contrast())
        }
        if arguments.contains(LaunchCommand.checkStrings.rawValue) {
            finish(succeeded: Checks.strings())
        }
        if arguments.contains(LaunchCommand.selfTest.rawValue) { runSelfTest() }
        if let iconFile = value(after: .renderIcon, in: arguments) {
            finish(succeeded: Checks.renderIcon(to: iconFile))
        }
        SpeicherExplorerApp.main()
    }

    private static func finish(succeeded: Bool) -> Never {
        exit(succeeded ? EXIT_SUCCESS : EXIT_FAILURE)
    }

    private static func runSelfTest() -> Never {
        Task.detached {
            SelfTest.run()
            exit(EXIT_SUCCESS)
        }
        dispatchMain()
    }

    /// The value given after a launch command, such as the file the icon is rendered into.
    private static func value(after command: LaunchCommand, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: command.rawValue), index + 1 < arguments.count
        else { return nil }
        return arguments[index + 1]
    }
}

struct SpeicherExplorerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window(TextKey.appName.translated, id: WindowID.main) {
            RootView()
                .environment(model)
                .frame(minWidth: Layout.minWindowWidth, minHeight: Layout.minWindowHeight)
        }
        .commands {
            LayoutCommands()
            // The system item would use the jerky AppKit toggle.
            CommandGroup(replacing: .sidebar) {
                Button(
                    model.isSidebarShown
                        ? TextKey.hideSidebar.translated : TextKey.showSidebar.translated
                ) { model.toggleSidebar() }
                .keyboardShortcut("s", modifiers: [.control, .command])
            }
            CommandGroup(after: .newItem) {
                Button(TextKey.rescan.translated) { model.scan() }.keyboardShortcut("r")
                    .disabled(model.isScanning)
                Button(TextKey.cancelScan.translated) { model.cancelScan() }.keyboardShortcut(".")
                    .disabled(!model.isScanning)
            }
        }
        Settings {
            SettingsView().environment(model)
        }
    }
}

/// Gives every window the app's locale for dates and numbers; used by every window so none can
/// forget it.
private struct PreferenceSync: ViewModifier {
    func body(content: Content) -> some View {
        content.environment(\.locale, Localizer.shared.locale)
    }
}

extension View {
    func syncPreferences() -> some View { modifier(PreferenceSync()) }
}

/// "View" menu entries like Finder's: ⌘1 shows lists, ⌘2 shows tiles.
private struct LayoutCommands: Commands {
    @AppStorage(SettingsKey.layoutMode) private var layoutMode = LayoutMode.list

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            ForEach(LayoutMode.allCases) { mode in
                Toggle(
                    mode.title.translated,
                    isOn: Binding(
                        get: { layoutMode == mode },
                        set: { isOn in if isOn { layoutMode = mode } })
                )
                .keyboardShortcut(mode == .list ? "1" : "2")
            }
            Divider()
        }
    }
}
