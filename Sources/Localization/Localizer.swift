import Foundation
import Observation

/// Looks up texts in `Resources/<code>.lproj/Localizable.strings` for the chosen language.
/// Views read it while rendering, so switching the language updates every window right away.
@Observable final class Localizer {
    static let shared = Localizer()

    private(set) var language = AppLanguage.system
    private(set) var locale = Locale.current
    private var bundle = Bundle.main

    private init() { apply(AppSettings.language) }

    func apply(_ choice: AppLanguage) {
        language = choice
        locale = Locale(identifier: choice.code)
        bundle = Self.bundle(for: choice.code) ?? .main
    }

    func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    static func bundle(for code: String) -> Bundle? {
        Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:))
    }
}

extension Loc {
    /// The text in the current language.
    var s: String { Localizer.shared.string(rawValue) }

    /// The text with `%@` placeholders filled in.
    func f(_ args: CVarArg...) -> String {
        String(format: s, locale: Localizer.shared.locale, arguments: args)
    }
}
