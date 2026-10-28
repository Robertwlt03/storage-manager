import Foundation

/// A few plain sentences about the storage, for reading at a glance or aloud.
enum SummaryService {
    static let topCategories = 2

    struct Input {
        let volume: VolumeInfo?
        let categories: [Category]
        let cleanable: Int64?
        let copies: Int64
        let unusedApps: Int
    }

    static func text(_ i: Input) -> String {
        var sentences: [String] = []
        if let v = i.volume {
            sentences.append(Loc.summaryDisk.f(v.name, Fmt.bytes(v.used), Fmt.bytes(v.total), Fmt.bytes(v.available)))
        }
        let top = i.categories.filter { !CategoryKind.estimated.contains($0.kind) }.prefix(topCategories)
        if top.count == topCategories {
            sentences.append(Loc.summaryTop.f(top[top.startIndex].kind.title.s, Fmt.bytes(top[top.startIndex].bytes),
                                              top[top.startIndex + 1].kind.title.s, Fmt.bytes(top[top.startIndex + 1].bytes)))
        } else if i.categories.isEmpty {
            sentences.append(Loc.summaryNotMeasured.s)
        }
        if let c = i.cleanable, c > 0 { sentences.append(Loc.summaryClean.f(Fmt.bytes(c))) }
        if i.copies > 0 { sentences.append(Loc.summaryCopies.f(Fmt.bytes(i.copies))) }
        if i.unusedApps > 0 { sentences.append(Loc.summaryApps.f(Fmt.count(i.unusedApps))) }
        return sentences.joined(separator: " ")
    }
}
