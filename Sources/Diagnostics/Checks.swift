import AppKit
import SwiftUI

/// Checks run by build.sh; each prints its findings and returns false on failure.
enum Checks {
    private static let minimumContrast = 4.5
    private static let whiteText: UInt32 = 0xFFFFFF
    private static let hexadecimal = 16
    /// Returned by the bundle instead of a text when a key is missing.
    private static let missingTextMarker = "\u{0}"

    // MARK: Contrast

    /// Every text tone against every light and dark surface reaches WCAG AA.
    static func contrast() -> Bool {
        let textTonesPass = checkTextTones()
        let fillsPass = checkFills()
        return textTonesPass && fillsPass
    }

    private static func checkTextTones() -> Bool {
        var allPass = true
        for (isDark, surfaces) in [(false, Theme.lightSurfaces), (true, Theme.darkSurfaces)] {
            for (name, tone) in Theme.textTones {
                for surface in surfaces {
                    let ratio = Theme.ratio(isDark ? tone.dark : tone.light, surface)
                    let label = "\(name) / #\(String(surface, radix: hexadecimal))"
                    allPass = report(ratio, label) && allPass
                }
            }
        }
        return allPass
    }

    private static func checkFills() -> Bool {
        var allPass = true
        for (name, fill) in Theme.fills {
            for colour in [fill.light, fill.dark] {
                let ratio = Theme.ratio(whiteText, colour)
                let label = "white / \(name) #\(String(colour, radix: hexadecimal))"
                allPass = report(ratio, label) && allPass
            }
        }
        return allPass
    }

    /// Prints one pair of colours and tells whether it reaches the minimum contrast.
    private static func report(_ ratio: Double, _ label: String) -> Bool {
        let passes = ratio >= minimumContrast
        let verdict = passes ? "ok  " : "FAIL"
        print("\(verdict) \(String(format: "%5.2f", ratio)):1  \(label)")
        return passes
    }

    // MARK: Texts

    /// Every `TextKey` key exists in every language, with the same number of placeholders.
    static func strings() -> Bool {
        let bundles = AppLanguage.allCases.map { language in
            (code: language.rawValue, bundle: Localizer.bundle(for: language.rawValue))
        }
        let everyKeyExists = checkEveryKeyExists(in: bundles)
        let placeholdersMatch = checkPlaceholdersMatch(in: bundles.compactMap(\.bundle))
        let languagesMatch = checkLanguageMatching()
        let allPass = everyKeyExists && placeholdersMatch && languagesMatch
        print(
            "\(TextKey.allCases.count) texts checked in \(bundles.count) languages: "
                + (allPass ? "ok" : "errors"))
        return allPass
    }

    private static func checkEveryKeyExists(in bundles: [(code: String, bundle: Bundle?)]) -> Bool {
        var allPass = true
        for (code, bundle) in bundles {
            guard let bundle else {
                print("FAIL \(code).lproj is missing")
                allPass = false
                continue
            }
            for key in TextKey.allCases where isMissing(key, in: bundle) {
                print("FAIL \(code): \(key.rawValue) is missing")
                allPass = false
            }
        }
        return allPass
    }

    private static func isMissing(_ key: TextKey, in bundle: Bundle) -> Bool {
        let text = bundle.localizedString(
            forKey: key.rawValue, value: missingTextMarker, table: nil)
        return text == missingTextMarker
    }

    private static func checkPlaceholdersMatch(in bundles: [Bundle]) -> Bool {
        var allPass = true
        for key in TextKey.allCases {
            let placeholderCounts = Set(
                bundles.map { bundle in
                    bundle.localizedString(forKey: key.rawValue, value: nil, table: nil)
                        .components(separatedBy: "%").count
                })
            if placeholderCounts.count > 1 {
                print("FAIL placeholders in \(key.rawValue) differ")
                allPass = false
            }
        }
        return allPass
    }

    /// System languages map to the shipped ones, including script and regional variants.
    private static func checkLanguageMatching() -> Bool {
        let expected: [(String, AppLanguage?)] = [
            ("de-DE", .de), ("en-GB", .en), ("zh-TW", .zhHant), ("zh-Hans-CN", .zhHans),
            ("zh-HK", .zhHant), ("pt-PT", .ptBR), ("no", .nb), ("nb-NO", .nb), ("xx", nil),
        ]
        var allPass = true
        for (identifier, language) in expected where AppLanguage.match(identifier) != language {
            print("FAIL language \(identifier) is matched to the wrong one")
            allPass = false
        }
        return allPass
    }

    // MARK: Icon

    @MainActor static func renderIcon(to path: String) -> Bool {
        guard let image = ImageRenderer(content: AppIconView()).cgImage,
            let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { return false }
        return (try? png.write(to: URL(fileURLWithPath: path))) != nil
    }
}
