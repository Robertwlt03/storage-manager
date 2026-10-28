import AppKit
import SwiftUI

/// A colour with one value for light and one for dark mode.
struct Tone {
    let light: UInt32
    let dark: UInt32

    var color: Color {
        Color(nsColor: NSColor(name: nil) { [light, dark] appearance in
            NSColor(hex: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light)
        })
    }
}

enum Theme {
    // Surfaces
    static let background = Tone(light: 0xF5F5F7, dark: 0x161618)
    static let card = Tone(light: 0xFFFFFF, dark: 0x232326)
    static let track = Tone(light: 0xE2E2E7, dark: 0x3A3A3F)  // empty part of bars, hovered rows
    static let tile = Tone(light: 0x26262B, dark: 0x0E0E10)  // dark tile behind the pixel icons

    // Text
    static let text = Tone(light: 0x1D1D1F, dark: 0xF2F2F7)
    static let muted = Tone(light: 0x55555A, dark: 0xB4B4BC)
    static let accent = Tone(light: 0x0A5BC4, dark: 0x6CB6FF)
    static let good = Tone(light: 0x166B2D, dark: 0x5FD07A)
    static let warn = Tone(light: 0x984200, dark: 0xFFA552)
    static let bad = Tone(light: 0xC0182A, dark: 0xFF8C8C)
    static let free = Tone(light: 0x00656C, dark: 0x4FD1D9)

    // Fills with white text on top
    static let buttonFill = Tone(light: 0x0A5BC4, dark: 0x1F6FD0)
    static let danger = Tone(light: 0xC0182A, dark: 0xC0182A)

    // Graphics only (ring, bars)
    static let usedRing = Tone(light: 0xB03AA8, dark: 0xD75FD7)
    static let freeRing = Tone(light: 0x00939A, dark: 0x00AFAF)

    /// Prints every text/surface pair in both modes; false if one is below 4.5:1 (WCAG AA).
    static func checkContrast() -> Bool {
        let texts = [("Text", text), ("Gedämpft", muted), ("Akzent", accent), ("Grün", good),
                     ("Orange", warn), ("Rot", bad), ("Frei", free)]
        let surfaces = [("Hintergrund", background), ("Karte", card), ("Hover", track)]
        var pairs: [(String, UInt32, UInt32)] = []
        for (dark, mode) in [(false, "hell"), (true, "dunkel")] {
            for (tn, t) in texts {
                for (sn, s) in surfaces { pairs.append(("\(tn) auf \(sn) (\(mode))", dark ? t.dark : t.light, dark ? s.dark : s.light)) }
            }
            for (fn, f) in [("Knopf", buttonFill), ("Löschen-Knopf", danger)] {
                pairs.append(("Weiß auf \(fn) (\(mode))", 0xFFFFFF, dark ? f.dark : f.light))
            }
        }
        var ok = true
        for (name, fg, bg) in pairs {
            let r = ratio(fg, bg)
            ok = ok && r >= 4.5
            print("\(r >= 4.5 ? "ok  " : "FAIL") \(String(format: "%5.2f", r)):1  \(name)")
        }
        return ok
    }

    static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        func luminance(_ hex: UInt32) -> Double {
            let c = [16, 8, 0].map { shift -> Double in
                let v = Double((hex >> UInt32(shift)) & 0xFF) / 255
                return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
        }
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}

extension ShapeStyle where Self == Color {
    static var bg: Color { Theme.background.color }
    static var card: Color { Theme.card.color }
    static var track: Color { Theme.track.color }
    static var tile: Color { Theme.tile.color }
    static var fg: Color { Theme.text.color }
    static var muted: Color { Theme.muted.color }
    static var accentText: Color { Theme.accent.color }
    static var good: Color { Theme.good.color }
    static var warn: Color { Theme.warn.color }
    static var bad: Color { Theme.bad.color }
    static var freeText: Color { Theme.free.color }
    static var buttonFill: Color { Theme.buttonFill.color }
    static var danger: Color { Theme.danger.color }
    static var usedRing: Color { Theme.usedRing.color }
    static var freeRing: Color { Theme.freeRing.color }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) { self.init(nsColor: NSColor(hex: hex)) }
}
