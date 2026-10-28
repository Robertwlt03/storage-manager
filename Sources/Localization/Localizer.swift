import Foundation

/// Looks up texts in `Resources/<code>.lproj/Localizable.strings` for the system's language.
final class Localizer {
    static let shared = Localizer()

    let locale: Locale
    private let bundle: Bundle

    private init() {
        let code = AppLanguage.current.rawValue
        locale = Locale(identifier: code)
        bundle = Self.bundle(for: code) ?? .main
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
