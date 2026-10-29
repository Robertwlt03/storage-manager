import AppKit

/// Code-signature copies in the temporary folder X, for any app.
enum CopyService {
    static let folderSuffix = ".code_sign_clone"
    static let appSuffixes = [".app", ".app.bundle"]
    static let versionKey = "CFBundleShortVersionString"

    static func groups(in folderX: Node?) -> [CopyGroup] {
        (folderX?.children ?? []).filter { $0.name.hasSuffix(folderSuffix) }.map(group)
    }

    static func isRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    /// Reads one Info.plist and one date per copy, on demand.
    static func details(_ group: CopyGroup) -> CopyDetails {
        let fm = FileManager.default
        var d = CopyDetails()
        var versions: [String: Int] = [:]
        var days: [Date: Int] = [:]
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
        for dir
            in (try? fm.contentsOfDirectory(
                at: group.node.url, includingPropertiesForKeys: Array(keys))) ?? []
        {
            let v = try? dir.resourceValues(forKeys: keys)
            guard v?.isDirectory == true else { continue }
            d.count += 1
            if let date = v?.contentModificationDate {
                days[Calendar.current.startOfDay(for: date), default: 0] += 1
            }
            let app = (try? fm.contentsOfDirectory(atPath: dir.path))?
                .first { n in appSuffixes.contains(where: n.hasSuffix) }
            versions[
                app.flatMap { version(at: dir.path + "/" + $0) } ?? TextKey.unknown.translated,
                default: 0] += 1
        }
        d.versions = versions.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
        d.days = days.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        return d
    }

    static func delete(_ group: CopyGroup) async throws {
        let url = group.node.url
        try await Task.detached(priority: .utility) { try FileManager.default.removeItem(at: url) }
            .value
    }

    private static func group(_ node: Node) -> CopyGroup {
        let bundleID = String(node.name.dropLast(folderSuffix.count))
        let appPath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path
        return CopyGroup(
            node: node, bundleID: bundleID, appPath: appPath,
            appName: appPath.map { FileManager.default.displayName(atPath: $0) } ?? bundleID,
            installedVersion: appPath.flatMap(version))
    }

    private static func version(at appPath: String) -> String? {
        NSDictionary(contentsOfFile: appPath + "/Contents/Info.plist")?[versionKey] as? String
    }
}

extension Node {
    fileprivate var url: URL { URL(fileURLWithPath: path) }
}
