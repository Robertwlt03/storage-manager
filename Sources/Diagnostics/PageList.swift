/// `SpeicherExplorer --list-pages` prints the launch key of every page, one per line, so scripts
/// such as scripts/snapshots.swift never keep their own copy of the list.
enum PageList {
    static func printLaunchKeys() {
        print(Pane.everyPage.map(\.launchKey).joined(separator: "\n"))
    }
}
