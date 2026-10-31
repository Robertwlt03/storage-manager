import Foundation
import Testing

@testable import StorageManager

/// The 28 translations under Resources, read straight from the project folder.
@Suite("Translations")
struct TranslationTests {
    private static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Resources")

    private static func texts(of language: AppLanguage) -> [String: String]? {
        let file = resources.appendingPathComponent(
            language.rawValue + ".lproj/Localizable.strings")
        return NSDictionary(contentsOf: file) as? [String: String]
    }

    private static func placeholderCount(_ text: String) -> Int {
        text.components(separatedBy: "%").count
    }

    @Test("Every text has as many placeholders as in English", arguments: AppLanguage.allCases)
    func placeholdersMatch(language: AppLanguage) throws {
        let english = try #require(Self.texts(of: .english))
        let translated = try #require(Self.texts(of: language))
        for (key, englishText) in english {
            let translatedText = translated[key] ?? ""
            #expect(
                Self.placeholderCount(translatedText) == Self.placeholderCount(englishText),
                "\(language.rawValue): \(key)")
        }
    }

    @Test("Every translation file is readable", arguments: AppLanguage.allCases)
    func fileIsReadable(language: AppLanguage) {
        #expect(Self.texts(of: language) != nil, "\(language.rawValue)")
    }

    @Test(
        "Every translation file holds exactly the keys the app uses",
        arguments: AppLanguage.allCases)
    func noLeftoverTexts(language: AppLanguage) throws {
        let texts = try #require(Self.texts(of: language))
        let usedKeys = Set(TextKey.allCases.map(\.rawValue))
        #expect(Set(texts.keys) == usedKeys, "\(language.rawValue)")
    }

    @Test(
        "System languages lead to the shipped ones, including script and regional variants",
        arguments: [
            ("de-DE", AppLanguage.german), ("en-GB", .english), ("zh-TW", .traditionalChinese),
            ("zh-Hans-CN", .simplifiedChinese), ("zh-HK", .traditionalChinese),
            ("pt", .brazilianPortuguese), ("pt-BR", .brazilianPortuguese),
            ("pt-PT", .europeanPortuguese), ("pt-AO", .europeanPortuguese),
            ("no", .norwegian), ("nb-NO", .norwegian),
            ("hi-IN", .hindi), ("el-GR", .greek),
        ])
    func languageMatching(systemLanguage: String, shipped: AppLanguage) {
        #expect(AppLanguage.match(systemLanguage) == shipped)
    }

    @Test("The language menu names every language in itself, sorted by that name")
    func nativeNames() {
        #expect(AppLanguage.german.nativeName == "Deutsch")
        #expect(AppLanguage.japanese.nativeName == "日本語")
        #expect(AppLanguage.greek.nativeName == "Ελληνικά")
        let names = AppLanguage.byNativeName.map(\.nativeName)
        #expect(Set(names).count == AppLanguage.allCases.count)
        let sorted = names.sorted { left, right in
            left.localizedStandardCompare(right) == .orderedAscending
        }
        #expect(names == sorted)
    }

    @Test("An unknown language falls back to none, so English takes over")
    func unknownLanguage() {
        #expect(AppLanguage.match("xx") == nil)
        #expect(AppLanguage.fallback == .english)
    }
}
