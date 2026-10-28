import AppKit

enum LifecycleService {
    /// Quits and opens the app again; macOS applies a newly granted Full Disk Access only to a new process.
    static func relaunch() {
        let script = "sleep 1; /usr/bin/open \"\(Bundle.main.bundlePath)\""
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script]
        try? p.run()
        NSApp.terminate(nil)
    }
}
