import SwiftUI

/// Looks up texts in `Resources/<code>.lproj/Localizable.strings` for the system's language.
nonisolated final class Localizer: Sendable {
    static let shared = Localizer()

    let locale: Locale
    /// The language picked in the settings at launch; a different choice needs a restart.
    let chosenAtLaunch = AppLanguage.chosen
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

extension View {
    /// Gives a window the app's locale for dates and numbers; every window calls it.
    func appLocale() -> some View { environment(\.locale, Localizer.shared.locale) }
}
