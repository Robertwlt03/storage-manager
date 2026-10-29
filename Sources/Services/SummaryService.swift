import Foundation

/// A few plain sentences about the storage, for reading at a glance or aloud.
enum SummaryService {
    private static let largestCategoryCount = 2

    struct Input {
        let volume: VolumeInfo?
        let categories: [Category]
        let cleanable: Int64?
        let copies: Int64
        let unusedApps: Int
    }

    static func text(_ input: Input) -> String {
        var sentences: [String] = []
        if let volume = input.volume {
            sentences.append(diskSentence(volume))
        }
        if let categoriesSentence = largestCategoriesSentence(input.categories) {
            sentences.append(categoriesSentence)
        }
        if let cleanableBytes = input.cleanable, cleanableBytes > 0 {
            sentences.append(TextKey.summaryClean.translated(with: Format.bytes(cleanableBytes)))
        }
        if input.copies > 0 {
            sentences.append(TextKey.summaryCopies.translated(with: Format.bytes(input.copies)))
        }
        if input.unusedApps > 0 {
            sentences.append(TextKey.summaryApps.translated(with: Format.count(input.unusedApps)))
        }
        return sentences.joined(separator: " ")
    }

    private static func diskSentence(_ volume: VolumeInfo) -> String {
        TextKey.summaryDisk.translated(
            with: volume.name, Format.bytes(volume.usedBytes), Format.bytes(volume.totalBytes),
            Format.bytes(volume.availableBytes))
    }

    private static func largestCategoriesSentence(_ categories: [Category]) -> String? {
        let measured = categories.filter { category in
            !CategoryKind.estimated.contains(category.kind)
        }
        let largest = measured.prefix(largestCategoryCount)
        if largest.count == largestCategoryCount, let first = largest.first,
            let second = largest.last
        {
            return TextKey.summaryTop.translated(
                with: first.kind.title.translated, Format.bytes(first.bytes),
                second.kind.title.translated, Format.bytes(second.bytes))
        }
        return categories.isEmpty ? TextKey.summaryNotMeasured.translated : nil
    }
}
