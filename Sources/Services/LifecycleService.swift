import AppKit

enum LifecycleService {
    /// Opens a new instance of the app, then quits this one; macOS applies a newly granted Full
    /// Disk Access only to a new process. Quitting with `exit` also works while a sheet is open,
    /// which blocks `terminate`.
    @MainActor static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
        {
            _, error in
            guard error == nil else { return }
            DispatchQueue.main.async { exit(EXIT_SUCCESS) }
        }
    }
}
