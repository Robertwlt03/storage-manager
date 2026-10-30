import Foundation
import Testing

@testable import SpeicherExplorer

/// Sizes, numbers and dates in the app's language. The words depend on the system's language, so
/// these tests check what holds in every language: digits, units and that different values read
/// differently.
@Suite("Formatting")
struct FormatTests {
    private static let oneDay: TimeInterval = 86_400
    private static let firstDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Sizes show a number and a unit, and a larger size a larger unit")
    func sizes() {
        let small = Format.bytes(1_000_000)
        let large = Format.bytes(3_000_000_000)
        let showsDigits = small.contains(where: \.isNumber)
        #expect(showsDigits)
        // Megabytes and gigabytes, in the letters of whatever language the system speaks.
        #expect(unit(of: small) != unit(of: large))
    }

    private func unit(of size: String) -> String {
        size.filter(\.isLetter)
    }

    @Test("Counts and shares keep their digits")
    func countsAndShares() {
        #expect(Format.count(42).contains("42"))
        #expect(Format.percent(0.5).contains("50"))
        #expect(!Format.percent(0.5).contains("."))  // whole percents only
    }

    @Test("Each date style tells two different days apart")
    func dates() {
        let nextDay = Self.firstDate.addingTimeInterval(Self.oneDay)
        let styles: [(Date) -> String] = [
            Format.day, Format.numericDay, Format.dateTime,
        ]
        for style in styles {
            #expect(style(Self.firstDate) != style(nextDay))
        }
        #expect(!Format.time(Self.firstDate).isEmpty)
    }

    @Test("One copy and several copies read differently")
    func copies() {
        #expect(Format.copies(1) != Format.copies(3))
    }

    @Test("Parts of a subtitle are joined by a middle dot")
    func joinedParts() {
        #expect(Format.joined("first", "second") == "first · second")
    }
}
