import Foundation

enum Paths {
    static let home = FileManager.default.homeDirectoryForCurrentUser.path
    static let applications = "/Applications"
    static let library = "/Library"
    static let opt = "/opt"
    static let usrLocal = "/usr/local"

    /// Per-user area under /private/var/folders/… with the subfolders T, C, X and 0.
    static let tempArea: String = {
        var buf = [CChar](repeating: 0, count: Int(PATH_MAX))
        confstr(_CS_DARWIN_USER_TEMP_DIR, &buf, buf.count)
        return real((String(cString: buf) as NSString).deletingLastPathComponent)
    }()

    static var tempCopies: String { tempArea + "/" + TempPart.x.rawValue }

    /// Areas measured on every Mac; missing ones are skipped.
    static var defaultScanRoots: [String] { [home, applications, library, opt, usrLocal, tempArea] }

    /// `~/…` to an absolute path.
    static func expand(_ path: String) -> String { path.hasPrefix("~") ? home + path.dropFirst() : path }

    /// Resolves symlinks like `pwd -P` (URL.resolvingSymlinksInPath would drop the /private prefix).
    static func real(_ path: String) -> String {
        guard let r = realpath(path, nil) else { return path }
        defer { free(r) }
        return String(cString: r)
    }

    static func display(_ path: String) -> String {
        if path == tempArea { return Loc.tempAreaName.s }
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    static func exists(_ path: String) -> Bool { FileManager.default.fileExists(atPath: path) }
}
