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
    // Secondary and status text. The system's secondary label colour reaches only about 4:1 in light mode,
    // so text uses these tones; surfaces and controls stay native.
    static let muted = Tone(light: 0x55555A, dark: 0xB4B4BC)
    static let good = Tone(light: 0x166B2D, dark: 0x5FD07A)
    static let warn = Tone(light: 0x984200, dark: 0xFFA552)
    static let bad = Tone(light: 0xB3141F, dark: 0xFF8C8C)
    static let textTones: [(name: String, tone: Tone)] = [("muted", muted), ("good", good), ("warn", warn), ("bad", bad)]

    // Button fills with white text on top.
    static let primaryFill = Tone(light: 0x0A5BC4, dark: 0x1F6FD0)
    static let confirmFill = Tone(light: 0x1B7332, dark: 0x1B7332)
    static let fills: [(name: String, tone: Tone)] = [("primaryFill", primaryFill), ("confirmFill", confirmFill)]

    /// Approximations of the system surfaces (content, window, grouped rows, sidebar, glass over the backdrop).
    static let lightSurfaces: [UInt32] = [0xFFFFFF, 0xF5F5F7, 0xECECEC, 0xE3E3E3, 0xDDE3EE]
    static let darkSurfaces: [UInt32] = [0x1E1E1E, 0x262626, 0x2D2D2D, 0x323232, 0x3A3A3A, 0x28303E]

    /// Category colours: Apple's light system colours, and in dark mode deeper shades instead of the brighter ones
    /// SwiftUI would pick, so the white symbols on the badges stay easy to see.
    static let colourful: [Tone] = [
        Tone(light: 0x007AFF, dark: 0x0A5BC4),  // blue
        Tone(light: 0xAF52DE, dark: 0x8034B0),  // purple
        Tone(light: 0xFF2D55, dark: 0xC2183F),  // pink
        Tone(light: 0xFF9500, dark: 0xB35A00),  // orange
        Tone(light: 0xFFCC00, dark: 0x8F6A00),  // yellow
        Tone(light: 0x34C759, dark: 0x1E7A38),  // green
        Tone(light: 0x30B0C7, dark: 0x16707F),  // teal
        Tone(light: 0x5856D6, dark: 0x4341B8),  // indigo
        Tone(light: 0xFF3B30, dark: 0xC0261E),  // red
        Tone(light: 0xA2845E, dark: 0x7A6145),  // brown
        Tone(light: 0x00C7BE, dark: 0x007A73),  // mint
        Tone(light: 0x32ADE6, dark: 0x1B6E99),  // cyan
        Tone(light: 0x8E8E93, dark: 0x5E5E63),  // gray
        Tone(light: 0x007AFF, dark: 0x0A5BC4),  // blue
        Tone(light: 0xAF52DE, dark: 0x8034B0),  // purple
        Tone(light: 0xAEAEB2, dark: 0x636366),  // light gray
    ]
    static let freeSegment = Color.gray.opacity(0.25)
    /// White symbols are graphics, not text: WCAG asks for 3:1 there.
    static let minSymbolContrast = 3.0

    static func color(_ index: Int, _ palette: ChartPalette) -> Color {
        switch palette {
        case .colourful: colourful[index % colourful.count].color
        case .accent: Color.accentColor.opacity(1 - Double(index % 7) * 0.11)
        case .greys: Color(white: 0.25 + Double(index % 8) * 0.08)
        }
    }

    /// WCAG contrast ratio of two sRGB colours.
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
    static var muted: Color { Theme.muted.color }
    static var good: Color { Theme.good.color }
    static var warn: Color { Theme.warn.color }
    static var bad: Color { Theme.bad.color }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
