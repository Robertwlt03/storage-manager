import AppKit
import SwiftUI

@main
enum AppEntry {
    static func main() {
        AppSettings.registerDefaults()
        let arguments = CommandLine.arguments
        if arguments.contains(LaunchCommand.selfTest.rawValue) { runSelfTest() }
        if let iconFile = value(after: .renderIcon, in: arguments) {
            finish(succeeded: AppIconView.render(to: iconFile))
        }
        SpeicherExplorerApp.main()
    }

    private static func finish(succeeded: Bool) -> Never {
        exit(succeeded ? EXIT_SUCCESS : EXIT_FAILURE)
    }

    private static func runSelfTest() -> Never {
        Task { finish(succeeded: SelfTest.run()) }
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
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
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
                    model.sidebar.isShown
                        ? TextKey.hideSidebar.translated : TextKey.showSidebar.translated
                ) { model.toggleSidebar() }
                .keyboardShortcut("s", modifiers: [.control, .command])
            }
            // The system item would only beep while the access sheet is open.
            CommandGroup(replacing: .appTermination) {
                Button(TextKey.quitApp.translated(with: TextKey.appName.translated)) {
                    LifecycleService.quit()
                }
                .keyboardShortcut("q")
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

extension View {
    /// Gives a window the app's locale for dates and numbers; every window calls it.
    func appLocale() -> some View { environment(\.locale, Localizer.shared.locale) }
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

/// Applies a forced appearance (`-appearance`) and accepts the quit request macOS sends after Full
/// Disk Access is switched on ("Quit & Reopen"), also while the access sheet is open; macOS then
/// opens the app again.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_: Notification) {
        NSApp.appearance = AppSettings.launchAppearance
    }

    func applicationDidFinishLaunching(_: Notification) {
        NSAppleEventManager.shared()
            .setEventHandler(
                self, andSelector: #selector(quit(_:withReply:)),
                forEventClass: AEEventClass(kCoreEventClass),
                andEventID: AEEventID(kAEQuitApplication))
    }

    @objc private func quit(_: NSAppleEventDescriptor, withReply _: NSAppleEventDescriptor) {
        LifecycleService.quit()
    }
}
