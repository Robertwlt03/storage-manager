import SwiftUI

/// Looks up texts in `Resources/<code>.lproj/Localizable.strings` for the system's language, and in
/// the English file for a text that language lacks, as Apple's apps fall back to their own one.
nonisolated final class Localizer: Sendable {
    static let shared = Localizer()

    let locale: Locale
    /// The language picked in the settings at launch; a different choice needs a restart.
    let chosenAtLaunch = AppLanguage.chosen
    private let bundle: Bundle
    private let englishBundle: Bundle

    private init() {
        let languageCode = AppLanguage.current.rawValue
        locale = Locale(identifier: languageCode)
        bundle = Self.bundle(for: languageCode) ?? .main
        englishBundle = Self.bundle(for: AppLanguage.fallback.rawValue) ?? .main
    }

    func string(_ key: String) -> String {
        Self.text(key, in: bundle, english: englishBundle)
    }

    /// The text in the bundle's language, or the English one when that language lacks it, so a
    /// missing translation shows English and never the bare key.
    static func text(_ key: String, in bundle: Bundle, english: Bundle) -> String {
        let text = bundle.localizedString(forKey: key, value: missingMark, table: nil)
        guard text == missingMark else { return text }
        return english.localizedString(forKey: key, value: nil, table: nil)
    }

    /// What a lookup returns for a missing key, a character no text holds, so the English file is
    /// only read when it is needed.
    private static let missingMark = "\u{0}"

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

extension View {
    /// Gives a window the app's locale for dates and numbers; every window calls it.
    func appLocale() -> some View { environment(\.locale, Localizer.shared.locale) }
}
