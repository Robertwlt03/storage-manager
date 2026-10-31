import AppKit

enum LifecycleService {
    private static let argumentPairLength = 2  // a launch argument's name, then its value
    /// Quits the app. AppKit refuses to terminate while a sheet such as the access sheet is open
    /// and only beeps, so the app then quits directly, as `relaunch` does.
    static func quit() {
        let hasOpenSheet = NSApp.windows.contains { window in window.attachedSheet != nil }
        if hasOpenSheet { exit(EXIT_SUCCESS) }
        NSApp.terminate(nil)
    }

    /// Opens a new instance of the app, then quits this one with `exit`, as `quit` does with a
    /// sheet open; macOS applies a newly granted Full Disk Access only to a new process.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = argumentsToKeep(from: ProcessInfo.processInfo.arguments)
        let appURL = Bundle.main.bundleURL
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            guard error == nil else { return }
            Task { @MainActor in exit(EXIT_SUCCESS) }
        }
    }

    /// What this instance was started with, such as `-demo YES`, so the new one starts the same
    /// way. A language given at the start is left out, as it would override the one just picked.
    static func argumentsToKeep(from arguments: [String]) -> [String] {
        var kept = Array(arguments.dropFirst())  // the first is the program itself
        if let language = kept.firstIndex(of: "-" + SettingsKey.appLanguages) {
            let nameAndValue = language..<min(language + argumentPairLength, kept.endIndex)
            kept.removeSubrange(nameAndValue)
        }
        return kept
    }
}
