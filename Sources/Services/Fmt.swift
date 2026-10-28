import Foundation

/// Number, size and date formatting in the app's language.
enum Fmt {
    private static var locale: Locale { Localizer.shared.locale }

    static func bytes(_ b: Int64) -> String {
        b.formatted(.byteCount(style: .file).locale(locale))  // like Finder
    }

    static func count(_ n: Int) -> String { n.formatted(.number.locale(locale)) }
    static func percent(_ v: Double) -> String { v.formatted(.percent.precision(.fractionLength(0)).locale(locale)) }
    static func day(_ d: Date) -> String { d.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)) }
    static func dayShort(_ d: Date) -> String { d.formatted(Date.FormatStyle(date: .numeric, time: .omitted).locale(locale)) }
    static func dateTime(_ d: Date) -> String { d.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)) }
    static func time(_ d: Date) -> String { d.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)) }
    static func copies(_ n: Int) -> String { n == 1 ? Loc.copiesOne.s : Loc.copiesMany.f(count(n)) }

    /// "a · b", the separator used in subtitles.
    static func joined(_ parts: String...) -> String { parts.joined(separator: " · ") }
}
