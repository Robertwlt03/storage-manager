import AppKit
import SwiftUI

/// A colour with one value for light and one for dark mode.
struct Tone {
    let light: UInt32
    let dark: UInt32

    var color: Color {
        Color(
            nsColor: NSColor(name: nil) { [light, dark] appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return NSColor(hex: isDark ? dark : light)
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
    static let textTones: [(name: String, tone: Tone)] = [
        ("muted", muted), ("good", good), ("warn", warn), ("bad", bad),
    ]

    // Button fills with white text on top.
    static let primaryFill = Tone(light: 0x0A5BC4, dark: 0x1F6FD0)
    static let confirmFill = Tone(light: 0x1B7332, dark: 0x1B7332)
    static let fills: [(name: String, tone: Tone)] = [
        ("primaryFill", primaryFill), ("confirmFill", confirmFill),
    ]

    /// Approximations of the system surfaces (content, window, grouped rows, sidebar, glass over the backdrop).
    static let lightSurfaces: [UInt32] = [0xFFFFFF, 0xF5F5F7, 0xECECEC, 0xE3E3E3, 0xDDE3EE]
    static let darkSurfaces: [UInt32] = [
        0x1E1E1E, 0x262626, 0x2D2D2D, 0x323232, 0x3A3A3A, 0x28303E,
    ]

    // Native surfaces, which follow light and dark mode by themselves.
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    /// Tinted by `Motion.hoverTint` behind rows under the mouse.
    static let highlight = Color.primary
    /// Invisible, but still catches clicks, for example beside the floating sidebar.
    static let clickCatcher = Color.clear

    /// Category colours: Apple's dynamic system colours, which adapt to light, dark and increased contrast by themselves.
    /// The white symbols on them are decorative (a text label always names the category), so the 3:1 rule for
    /// meaningful graphics does not apply; all text keeps its 4.5:1 check.
    static let colourful: [Color] = [
        .blue, .purple, .pink, .orange, .yellow, .green, .teal, .indigo, .red, .brown, .mint,
        .cyan, .gray, .blue, .purple, .secondary,
    ]
    static let badgeSymbol = Color.white
    static let freeSegment = Color.gray.opacity(0.25)

    // The app icon: a white ring on a blue gradient, drawn the same in light and dark mode.
    static let appIconTop = Color(red: 0.36, green: 0.62, blue: 1.0)
    static let appIconBottom = Color(red: 0.12, green: 0.32, blue: 0.86)
    static let appIconShadow = Color.black.opacity(0.28)
    static let appIconRing = Color.white
    static let appIconRingTrack = appIconRing.opacity(0.22)

    static func color(_ index: Int) -> Color { colourful[index % colourful.count] }

    /// WCAG contrast ratio of two sRGB colours.
    static func ratio(_ first: UInt32, _ second: UInt32) -> Double {
        let firstLuminance = relativeLuminance(of: first)
        let secondLuminance = relativeLuminance(of: second)
        let lighter = max(firstLuminance, secondLuminance)
        let darker = min(firstLuminance, secondLuminance)
        return (lighter + flare) / (darker + flare)
    }

    // The WCAG 2 formula for relative luminance and contrast.
    private static let flare = 0.05
    private static let redWeight = 0.2126
    private static let greenWeight = 0.7152
    private static let blueWeight = 0.0722
    private static let linearLimit = 0.03928
    private static let linearSlope = 12.92
    private static let gammaOffset = 0.055
    private static let gammaScale = 1.055
    private static let gamma = 2.4

    private static func relativeLuminance(of hex: UInt32) -> Double {
        let channels = HexChannels(hex)
        let red = redWeight * linear(channels.red)
        let green = greenWeight * linear(channels.green)
        let blue = blueWeight * linear(channels.blue)
        return red + green + blue
    }

    private static func linear(_ channel: Double) -> Double {
        guard channel > linearLimit else { return channel / linearSlope }
        return pow((channel + gammaOffset) / gammaScale, gamma)
    }
}

extension ShapeStyle where Self == Color {
    static var muted: Color { Theme.muted.color }
    static var good: Color { Theme.good.color }
    static var warn: Color { Theme.warn.color }
    static var bad: Color { Theme.bad.color }
}

/// The red, green and blue parts of a colour written as one hex number such as 0x0A5BC4, each from 0 to 1.
private struct HexChannels {
    private static let redShift: UInt32 = 16
    private static let greenShift: UInt32 = 8
    private static let channelMask: UInt32 = 0xFF
    private static let channelMaximum = Double(channelMask)

    let red: Double
    let green: Double
    let blue: Double

    init(_ hex: UInt32) {
        red = Double((hex >> Self.redShift) & Self.channelMask) / Self.channelMaximum
        green = Double((hex >> Self.greenShift) & Self.channelMask) / Self.channelMaximum
        blue = Double(hex & Self.channelMask) / Self.channelMaximum
    }
}

extension NSColor {
    fileprivate convenience init(hex: UInt32) {
        let channels = HexChannels(hex)
        self.init(
            srgbRed: channels.red, green: channels.green, blue: channels.blue, alpha: Opacity.full)
    }
}
