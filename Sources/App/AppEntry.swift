import AppKit
import SwiftUI

@main
enum AppEntry {
    static func main() {
        AppSettings.registerDefaults()
        let arguments = CommandLine.arguments
        if arguments.contains(LaunchCommand.selfTest.rawValue) { runSelfTest() }
        if arguments.contains(LaunchCommand.listPages.rawValue) {
            PageList.printLaunchKeys()
            finish(succeeded: true)
        }
        if let iconFile = value(after: .renderIcon, in: arguments) {
            finish(succeeded: AppIconView.render(to: iconFile))
        }
        StorageManagerApp.main()
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

struct StorageManagerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var model = AppModel()
    @AppStorage(SettingsKey.showsMenuBarItem) private var showsMenuBarItem = true

    var body: some Scene {
        Window(TextKey.appName.translated, id: WindowID.main) {
            RootView()
                .environment(model)
                .frame(minWidth: Layout.minimumWindowWidth, minHeight: Layout.minimumWindowHeight)
        }
        .commands { menuCommands }
        Settings {
            SettingsView().environment(model)
        }
        MenuBarExtra(isInserted: $showsMenuBarItem) {
            MenuBarMenu().environment(model)
        } label: {
            MenuBarLabel().environment(model)
        }
        .menuBarExtraStyle(.menu)
    }

    @CommandsBuilder private var menuCommands: some Commands {
        // The system item would use the jerky AppKit toggle. The layout items share this group:
        // macOS drops a group placed before the replaced sidebar group.
        CommandGroup(replacing: .sidebar) {
            LayoutMenuItems(model: model)
            Divider()
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
            Divider()
            Button(TextKey.exportReport.translated) {
                FinderService.save(model.report(), suggestedName: TextKey.reportFileName.translated)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])  // ⌘E is Use Selection for Find
            .disabled(!model.hasData || model.isScanning)
        }
    }
}

/// "View" menu entries like Finder's, the same choices as the layout switch: ⌘1 shows lists, ⌘2
/// tiles and ⌘3 rings, which only Folders has.
private struct LayoutMenuItems: View {
    /// Its page decides which layouts the items offer.
    let model: AppModel
    @AppStorage(SettingsKey.layoutMode) private var layoutMode = LayoutMode.list
    @AppStorage(SettingsKey.showsRings) private var showsRings = false

    var body: some View {
        // Search results replace the page and have list and tiles only.
        let pane = model.isSearching ? nil : model.pane
        let selection = PageLayout.selection(on: pane, $layoutMode, $showsRings)
        let offered = PageLayout.choices(on: pane)
        ForEach(PageLayout.allCases) { layout in
            Toggle(
                layout.title.translated,
                isOn: Binding(
                    get: { selection.wrappedValue == layout },
                    set: { isOn in if isOn { selection.wrappedValue = layout } })
            )
            .keyboardShortcut(Self.shortcut(of: layout))
            .disabled(!offered.contains(layout))
        }
    }

    private static func shortcut(of layout: PageLayout) -> KeyEquivalent {
        switch layout {
        case .list: "1"
        case .grid: "2"
        case .rings: "3"
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

    /// With the menu bar item the app stays open without a window, like other menu bar apps.
    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        !AppSettings.showsMenuBarItem
    }

    @objc private func quit(_: NSAppleEventDescriptor, withReply _: NSAppleEventDescriptor) {
        LifecycleService.quit()
    }
}
