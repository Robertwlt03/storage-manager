import Foundation

nonisolated enum Paths {
    static let home = FileManager.default.homeDirectoryForCurrentUser.path
    static let applications = "/Applications"
    static let library = "/Library"
    static let opt = "/opt"
    static let usrLocal = "/usr/local"
    /// Where macOS mounts every volume except the startup volume.
    static let otherVolumes = "/Volumes"

    /// Per-user area under /private/var/folders/… with the subfolders T, C, X and 0.
    static let temporaryArea: String = {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, buffer.count)
        return withoutSymlinks(
            ((String(utf8String: buffer) ?? "") as NSString).deletingLastPathComponent)
    }()

    static var temporaryCopies: String {
        temporaryArea + "/" + TemporaryAreaPart.appCopies.rawValue
    }

    /// Areas measured on every Mac; missing ones are skipped.
    static var defaultScanRoots: [String] {
        [home, applications, library, opt, usrLocal, temporaryArea]
    }

    /// `~/…` to an absolute path.
    static func expand(_ path: String) -> String {
        path.hasPrefix("~") ? home + path.dropFirst() : path
    }

    /// Resolves symlinks like `pwd -P` (URL.resolvingSymlinksInPath would drop the /private
    /// prefix).
    static func withoutSymlinks(_ path: String) -> String {
        guard let resolvedPath = realpath(path, nil) else { return path }
        defer { free(resolvedPath) }
        return String(cString: resolvedPath)
    }

    /// The measured areas by their everyday name, also in front of what lies inside them, so no
    /// `~`, `/Applications` or the temporary area's long per-Mac path shows, nor in the demo.
    static func displayName(_ path: String) -> String {
        for (root, name) in namedRoots where path == root || path.hasPrefix(root + "/") {
            return name.translated + path.dropFirst(root.count)
        }
        return path
    }

    private static let namedRoots: [(path: String, name: TextKey)] = [
        (home, .homeFolderName), (applications, .categoryApps), (library, .categoryLibrary),
        (temporaryArea, .temporaryAreaName),
    ]

    static func exists(_ path: String) -> Bool { FileManager.default.fileExists(atPath: path) }
}
