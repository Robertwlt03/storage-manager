import AppKit
import SwiftUI

/// Checks run by build.sh; each prints its findings and returns false on failure.
enum Checks {
    static let minContrast = 4.5

    /// Every text tone against every light and dark surface reaches WCAG AA.
    static func contrast() -> Bool {
        var ok = true
        for (dark, surfaces) in [(false, Theme.lightSurfaces), (true, Theme.darkSurfaces)] {
            for (name, tone) in Theme.textTones {
                for s in surfaces {
                    let r = Theme.ratio(dark ? tone.dark : tone.light, s)
                    ok = ok && r >= minContrast
                    print("\(r >= minContrast ? "ok  " : "FAIL") \(String(format: "%5.2f", r)):1  \(name) / #\(String(s, radix: 16))")
                }
            }
        }
        for (name, fill) in Theme.fills {
            for hex in [fill.light, fill.dark] {
                let r = Theme.ratio(0xFFFFFF, hex)
                ok = ok && r >= minContrast
                print("\(r >= minContrast ? "ok  " : "FAIL") \(String(format: "%5.2f", r)):1  white / \(name) #\(String(hex, radix: 16))")
            }
        }
        return ok
    }

    /// Every `Loc` key exists in every language, with the same number of placeholders.
    static func strings() -> Bool {
        var ok = true
        let bundles = AppLanguage.allCases.map { ($0.rawValue, Localizer.bundle(for: $0.rawValue)) }
        for (code, bundle) in bundles {
            guard let bundle else {
                print("FAIL \(code).lproj fehlt")
                ok = false
                continue
            }
            for key in Loc.allCases {
                let text = bundle.localizedString(forKey: key.rawValue, value: "\u{0}", table: nil)
                if text == "\u{0}" {
                    print("FAIL \(code): \(key.rawValue) fehlt")
                    ok = false
                }
            }
        }
        let reference = bundles.compactMap(\.1)
        for key in Loc.allCases {
            let counts = Set(reference.map { $0.localizedString(forKey: key.rawValue, value: nil, table: nil).components(separatedBy: "%").count })
            if counts.count > 1 {
                print("FAIL Platzhalter in \(key.rawValue) unterscheiden sich")
                ok = false
            }
        }
        print("\(Loc.allCases.count) Texte in \(bundles.count) Sprachen geprüft: \(ok ? "ok" : "Fehler")")
        return ok
    }

    @MainActor static func renderIcon(to path: String) -> Bool {
        guard let cg = ImageRenderer(content: AppIconView()).cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return false }
        return (try? png.write(to: URL(fileURLWithPath: path))) != nil
    }
}
