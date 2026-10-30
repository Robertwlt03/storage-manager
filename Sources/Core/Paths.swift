import Foundation

nonisolated enum Paths {
    static let home = FileManager.default.homeDirectoryForCurrentUser.path
    static let applications = "/Applications"
    static let library = "/Library"
    static let opt = "/opt"
    static let usrLocal = "/usr/local"

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

    static func displayName(_ path: String) -> String {
        if path == temporaryArea { return TextKey.temporaryAreaName.translated }
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    static func exists(_ path: String) -> Bool { FileManager.default.fileExists(atPath: path) }
}
