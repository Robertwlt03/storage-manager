import AppKit
import SwiftUI

/// A color with one value for light and one for dark mode.
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
    // Secondary and status text. The system's secondary label color reaches only about 4:1 in
    // light mode, so text uses these tones; surfaces and controls stay native. DesignTests checks
    // every tone and fill against light and dark surfaces.
    static let muted = Tone(light: 0x55555A, dark: 0xB4B4BC)
    static let good = Tone(light: 0x166B2D, dark: 0x5FD07A)
    static let warning = Tone(light: 0x984200, dark: 0xFFA552)
    static let bad = Tone(light: 0xB3141F, dark: 0xFF8C8C)

    // The fill of primary buttons, with white text on top.
    static let primaryFill = Tone(light: 0x0A5BC4, dark: 0x1F6FD0)

    // The native window surface, which follows light and dark mode by itself.
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    /// Tinted by `Motion.hoverTint` behind rows under the mouse.
    static let highlight = Color.primary
    /// Invisible, but still catches clicks, for example beside the floating sidebar.
    static let clickCatcher = Color.clear

    /// Category colors, one of its own for every kind in `CategoryKind`'s order: Apple's dynamic
    /// system colors and blends of them, which adapt to light, dark and increased contrast by
    /// themselves. The white symbols on them are decorative (a text label always names the
    /// category), so the 3:1 rule for meaningful graphics does not apply; all text keeps its 4.5:1
    /// check. The rings reuse them for their branches, from the start once they run out.
    /// Close system pairs (red and pink, teal and mint) never both stand for a category.
    static let categoryColors: [Color] = [
        .blue,  // apps
        .purple,  // documents
        .yellow,  // downloads
        .orange,  // photos, music and movies
        .cyan,  // iCloud Drive
        .green,  // mail and messages
        .teal,  // developer
        .indigo,  // caches
        .red,  // app data
        .brown,  // Trash
        .green.mix(with: .black, by: blendShare),  // temporary files, a forest green
        .pink.mix(with: .purple, by: halfShare),  // other user data, an orchid
        .gray.mix(with: .blue, by: blendShare),  // shared app data, a slate
        .brown.mix(with: .yellow, by: blendShare),  // other files, a sand
        .green.mix(with: .yellow, by: blendShare),  // purgeable by macOS, a lime
        .gray,  // system and other
    ]
    private static let blendShare = 0.4
    private static let halfShare = 0.5
    static let badgeSymbol = Color.white
    /// Symbols and badges while the window is in the background, the gray of the sidebar's symbols.
    static let inBackground = Color.gray
    static let freeSegment = Color.gray.opacity(0.25)

    // The app icon: a white ring on a blue gradient, drawn the same in light and dark mode.
    static let appIconTop = Color(red: 0.36, green: 0.62, blue: 1.0)
    static let appIconBottom = Color(red: 0.12, green: 0.32, blue: 0.86)
    static let appIconShadow = Color.black.opacity(0.28)
    static let appIconRing = Color.white
    static let appIconRingTrack = appIconRing.opacity(0.22)

    static func categoryColor(_ index: Int) -> Color {
        categoryColors[index % categoryColors.count]
    }
}

extension ShapeStyle where Self == Color {
    static var muted: Color { Theme.muted.color }
    static var good: Color { Theme.good.color }
    static var warning: Color { Theme.warning.color }
    static var bad: Color { Theme.bad.color }
}

/// The red, green and blue parts of a color written as one hex number such as 0x0A5BC4, each from
/// 0 to 1.
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
