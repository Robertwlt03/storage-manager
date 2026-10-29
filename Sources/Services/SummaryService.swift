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
            sentences.append(
                TextKey.summaryDisk.translated(
                    with: v.name, Format.bytes(v.used), Format.bytes(v.total),
                    Format.bytes(v.available)))
        }
        let top = i.categories.filter { !CategoryKind.estimated.contains($0.kind) }
            .prefix(topCategories)
        if top.count == topCategories {
            sentences.append(
                TextKey.summaryTop.translated(
                    with: top[top.startIndex].kind.title.translated,
                    Format.bytes(top[top.startIndex].bytes),
                    top[top.startIndex + 1].kind.title.translated,
                    Format.bytes(top[top.startIndex + 1].bytes)))
        } else if i.categories.isEmpty {
            sentences.append(TextKey.summaryNotMeasured.translated)
        }
        if let c = i.cleanable, c > 0 {
            sentences.append(TextKey.summaryClean.translated(with: Format.bytes(c)))
        }
        if i.copies > 0 {
            sentences.append(TextKey.summaryCopies.translated(with: Format.bytes(i.copies)))
        }
        if i.unusedApps > 0 {
            sentences.append(TextKey.summaryApps.translated(with: Format.count(i.unusedApps)))
        }
        return sentences.joined(separator: " ")
    }
}
