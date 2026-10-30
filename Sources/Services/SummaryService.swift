import Foundation

/// A few plain sentences about the storage, for reading at a glance or aloud.
enum SummaryService {
    private static let largestCategoryCount = 2

    struct Input {
        let volume: VolumeInformation?
        let categories: [Category]
        let cleanableBytes: Int64?
        let copyBytes: Int64
        let unusedAppCount: Int
    }

    static func text(_ input: Input) -> String {
        var sentences: [String] = []
        if let volume = input.volume {
            sentences.append(diskSentence(volume))
        }
        if let categoriesSentence = largestCategoriesSentence(input.categories) {
            sentences.append(categoriesSentence)
        }
        if let cleanableBytes = input.cleanableBytes, cleanableBytes > 0 {
            sentences.append(TextKey.summaryClean.translated(with: Format.bytes(cleanableBytes)))
        }
        if input.copyBytes > 0 {
            sentences.append(TextKey.summaryCopies.translated(with: Format.bytes(input.copyBytes)))
        }
        if input.unusedAppCount > 0 {
            sentences.append(
                TextKey.summaryApps.translated(with: Format.count(input.unusedAppCount)))
        }
        return sentences.joined(separator: " ")
    }

    private static func diskSentence(_ volume: VolumeInformation) -> String {
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
