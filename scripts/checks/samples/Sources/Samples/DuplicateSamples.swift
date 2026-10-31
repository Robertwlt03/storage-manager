// swift-format-ignore-file

func firstReport(entries: [String]) -> String {
    let sortedEntries = entries.sorted { left, right in left < right }
    let joinedEntries = sortedEntries.joined(separator: ", ")
    let trimmedEntries = joinedEntries.trimmingCharacters(in: .whitespaces)
    let shownEntries = trimmedEntries.isEmpty ? "none" : trimmedEntries
    let countedEntries = "\(entries.count) entries: \(shownEntries)"
    let finishedReport = countedEntries.capitalized
    let quietReport = finishedReport.lowercased()
    return quietReport
}

func secondReport(entries: [String]) -> String {
    let sortedEntries = entries.sorted { left, right in left < right }  // expect: repeat
    let joinedEntries = sortedEntries.joined(separator: ", ")
    let trimmedEntries = joinedEntries.trimmingCharacters(in: .whitespaces)
    let shownEntries = trimmedEntries.isEmpty ? "none" : trimmedEntries
    let countedEntries = "\(entries.count) entries: \(shownEntries)"
    let finishedReport = countedEntries.capitalized
    let quietReport = finishedReport.lowercased()
    return quietReport
}
