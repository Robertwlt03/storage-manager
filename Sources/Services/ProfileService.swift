import Foundation

/// File types, counts and date range below a folder, for the info sheet (a second fts pass on demand).
enum ProfileService {
    static let packageSuffixes = [".app", ".bundle", ".framework"]
    static let topTypes = 10

    static func profile(_ path: String) -> FolderProfile {
        var r = FolderProfile()
        var bytes: [String: Int64] = [:]
        var counts: [String: Int] = [:]
        var oldest = Int.max
        var newest = 0
        var counter = 0

        FTS.walk(path) { ent in
            counter += 1
            if counter & ScanConfig.cancelCheckMask == 0 && Task.isCancelled { return false }
            switch FTS.info(ent) {
            case FTS_D:
                r.folders += 1
                let n = FTS.name(ent)
                if packageSuffixes.contains(where: n.hasSuffix) { r.packages += 1 }
            case FTS_F:
                guard let st = ent.pointee.fts_statp?.pointee else { return true }
                r.files += 1
                let ext = (FTS.name(ent) as NSString).pathExtension.lowercased()
                let key = ext.isEmpty ? TextKey.noExtension.translated : "." + ext
                bytes[key, default: 0] += FTS.allocated(st)
                counts[key, default: 0] += 1
                oldest = min(oldest, st.st_mtimespec.tv_sec)
                newest = max(newest, st.st_mtimespec.tv_sec)
            default:
                break
            }
            return true
        }
        if r.files > 0 {
            r.oldest = Date(timeIntervalSince1970: TimeInterval(oldest))
            r.newest = Date(timeIntervalSince1970: TimeInterval(newest))
        }
        r.folders = max(0, r.folders - 1)  // without the folder itself
        r.types = bytes.sorted { $0.value > $1.value }.prefix(topTypes)
            .map { ($0.key, $0.value, counts[$0.key] ?? 0) }
        return r
    }
}
