import AppKit

enum LifecycleService {
    /// Opens a new instance of the app, then quits this one; macOS applies a newly granted Full Disk Access
    /// only to a new process. Quitting with `exit` also works while a sheet is open, which blocks `terminate`.
    @MainActor static func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.async { exit(0) }
        }
    }
}
