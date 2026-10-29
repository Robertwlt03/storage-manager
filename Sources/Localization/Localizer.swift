import Foundation

/// Looks up texts in `Resources/<code>.lproj/Localizable.strings` for the system's language.
nonisolated final class Localizer: Sendable {
    static let shared = Localizer()

    let locale: Locale
    private let bundle: Bundle

    private init() {
        let languageCode = AppLanguage.current.rawValue
        locale = Locale(identifier: languageCode)
        bundle = Self.bundle(for: languageCode) ?? .main
    }

    func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    private static func bundle(for code: String) -> Bundle? {
        Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:))
    }
}

nonisolated extension TextKey {
    /// The text in the current language.
    var translated: String { Localizer.shared.string(rawValue) }

    /// The text with `%@` placeholders filled in.
    func translated(with values: CVarArg...) -> String {
        String(format: translated, locale: Localizer.shared.locale, arguments: values)
    }
}
