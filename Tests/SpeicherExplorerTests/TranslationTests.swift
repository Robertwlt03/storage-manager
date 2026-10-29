import Foundation
import Testing

@testable import SpeicherExplorer

/// The 20 translations under Resources, read straight from the project folder.
@Suite("Translations")
struct TranslationTests {
    private static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Resources")

    private static func bundle(for code: String) -> Bundle? {
        Bundle(url: resources.appendingPathComponent(code + ".lproj"))
    }

    @Test("Every text exists in every language, with the same placeholders")
    func everyTextIsTranslated() {
        #expect(Checks.strings(bundleForLanguage: Self.bundle))
    }

    @Test("Every translation file is readable", arguments: AppLanguage.allCases)
    func fileIsReadable(language: AppLanguage) {
        let file = Self.resources.appendingPathComponent(
            language.rawValue + ".lproj/Localizable.strings")
        #expect(NSDictionary(contentsOf: file) != nil, "\(language.rawValue)")
    }

    @Test(
        "Every translation file holds exactly the keys the app uses",
        arguments: AppLanguage.allCases)
    func noLeftoverTexts(language: AppLanguage) throws {
        let file = Self.resources.appendingPathComponent(
            language.rawValue + ".lproj/Localizable.strings")
        let texts = try #require(NSDictionary(contentsOf: file) as? [String: String])
        let usedKeys = Set(TextKey.allCases.map(\.rawValue))
        #expect(Set(texts.keys) == usedKeys, "\(language.rawValue)")
    }

    @Test(
        "System languages lead to the shipped ones, including script and regional variants",
        arguments: [
            ("de-DE", AppLanguage.de), ("en-GB", .en), ("zh-TW", .zhHant), ("zh-Hans-CN", .zhHans),
            ("zh-HK", .zhHant), ("pt-PT", .ptBR), ("no", .nb), ("nb-NO", .nb),
        ])
    func languageMatching(systemLanguage: String, shipped: AppLanguage) {
        #expect(AppLanguage.match(systemLanguage) == shipped)
    }

    @Test("An unknown language falls back to none, so English takes over")
    func unknownLanguage() {
        #expect(AppLanguage.match("xx") == nil)
        #expect(AppLanguage.fallback == .en)
    }
}
