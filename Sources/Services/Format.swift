import Foundation

/// Number, size and date formatting in the app's language.
enum Format {
    private static let wholePercentFractionDigits = 0
    private static var locale: Locale { Localizer.shared.locale }

    static func bytes(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file).locale(locale))  // like Finder
    }

    static func count(_ number: Int) -> String { number.formatted(.number.locale(locale)) }
    static func percent(_ fraction: Double) -> String {
        fraction.formatted(
            .percent.precision(.fractionLength(wholePercentFractionDigits)).locale(locale))
    }
    static func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }
    static func numericDay(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .numeric, time: .omitted).locale(locale))
    }
    static func dateTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
    }
    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }
    static func copies(_ copyCount: Int) -> String {
        copyCount == 1
            ? TextKey.copiesOne.translated : TextKey.copiesMany.translated(with: count(copyCount))
    }

    /// "a · b", the separator used in subtitles.
    static func joined(_ parts: String...) -> String { parts.joined(separator: " · ") }
}
