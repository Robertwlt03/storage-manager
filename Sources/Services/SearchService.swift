/// Searches folder and file names in the scanned tree. Instant and without disk access;
/// files under `ScanConfig.keepBytes` are folded during the scan and therefore not searchable.
enum SearchService {
    static func search(_ query: String, scope: SearchScope, in root: Node) -> [Entry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        var hits: [Entry] = []

        func walk(_ n: Node) {
            for child in n.children {
                if scope != .files && child.name.localizedStandardContains(q) {
                    hits.append(.folder(child))
                }
                walk(child)
            }
            if scope != .folders {
                hits += n.files.filter { $0.name.localizedStandardContains(q) }.map(Entry.file)
            }
        }
        walk(root)
        return Array(hits.sorted { $0.bytes > $1.bytes }.prefix(ScanConfig.searchLimit))
    }

    static func largeFiles(atLeast min: Int64, in root: Node) -> [Entry] {
        var out: [Entry] = []
        func walk(_ n: Node) {
            out += n.files.filter { $0.bytes >= min }.map(Entry.file)
            n.children.forEach(walk)
        }
        walk(root)
        return out.sorted { $0.bytes > $1.bytes }
    }
}
