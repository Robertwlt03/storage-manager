import AppKit

/// Code-signature copies in the temporary folder X, for any app.
nonisolated enum CopyService {
    private static let folderSuffix = ".code_sign_clone"
    private static let appSuffixes = [".app", ".app.bundle"]
    private static let versionKey = "CFBundleShortVersionString"
    private static let copyKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .contentModificationDateKey,
    ]

    static func groups(in copiesFolder: Node?) -> [CopyGroup] {
        let groupFolders = (copiesFolder?.children ?? [])
            .filter { folder in folder.name.hasSuffix(folderSuffix) }
        return groupFolders.map(group)
    }

    static func isRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    /// Reads one Info.plist and one date per copy, on demand.
    static func details(_ group: CopyGroup) -> CopyDetails {
        var details = CopyDetails()
        var copiesPerVersion: [String: Int] = [:]
        var copiesPerDay: [Date: Int] = [:]
        for copyFolder in contents(of: group.node.url) {
            let values = try? copyFolder.resourceValues(forKeys: copyKeys)
            guard values?.isDirectory == true else { continue }
            details.copyCount += 1
            if let modified = values?.contentModificationDate {
                copiesPerDay[Calendar.current.startOfDay(for: modified), default: 0] += 1
            }
            copiesPerVersion[appVersion(inCopy: copyFolder), default: 0] += 1
        }
        details.versions = copiesPerVersion.sorted { left, right in left.value > right.value }
            .map { version in (version.key, version.value) }
        details.days = copiesPerDay.sorted { left, right in left.key < right.key }
            .map { day in (day.key, day.value) }
        return details
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
            appName: appPath.map { path in FileManager.default.displayName(atPath: path) }
                ?? bundleID,
            installedVersion: appPath.flatMap(version))
    }

    private static func contents(of folder: URL) -> [URL] {
        let fileManager = FileManager.default
        let copyFolders = try? fileManager.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: Array(copyKeys))
        return copyFolders ?? []
    }

    private static func appVersion(inCopy copyFolder: URL) -> String {
        let appName = (try? FileManager.default.contentsOfDirectory(atPath: copyFolder.path))?
            .first { name in appSuffixes.contains(where: name.hasSuffix) }
        let copiedVersion = appName.flatMap { name in version(at: copyFolder.path + "/" + name) }
        return copiedVersion ?? TextKey.unknown.translated
    }

    private static func version(at appPath: String) -> String? {
        NSDictionary(contentsOfFile: appPath + "/Contents/Info.plist")?[versionKey] as? String
    }
}

nonisolated extension Node {
    fileprivate var url: URL { URL(fileURLWithPath: path) }
}
