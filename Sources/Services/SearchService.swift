/// Searches folder and file names in the scanned tree. Instant and without disk access; files
/// under `ScanLimits.smallestListedBytes` are folded during the scan and therefore not searchable.
enum SearchService {
    static func search(_ query: String, scope: SearchScope, in root: Node) -> [Entry] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else { return [] }
        var matches: [Entry] = []

        func collectMatches(in folder: Node) {
            for child in folder.children {
                let isMatch = scope != .files && child.name.localizedStandardContains(trimmedQuery)
                if isMatch { matches.append(.folder(child)) }
                collectMatches(in: child)
            }
            if scope != .folders {
                matches += folder.files
                    .filter { file in file.name.localizedStandardContains(trimmedQuery) }
                    .map(Entry.file)
            }
        }
        collectMatches(in: root)
        let biggestFirst = matches.sorted { left, right in left.bytes > right.bytes }
        return Array(biggestFirst.prefix(ScanLimits.maximumSearchResults))
    }

    static func largeFiles(atLeast minimumBytes: Int64, in root: Node) -> [Entry] {
        var largeFiles: [Entry] = []
        func collectLargeFiles(in folder: Node) {
            largeFiles += folder.files.filter { file in file.bytes >= minimumBytes }.map(Entry.file)
            folder.children.forEach(collectLargeFiles)
        }
        collectLargeFiles(in: root)
        return largeFiles.sorted { left, right in left.bytes > right.bytes }
    }
}
