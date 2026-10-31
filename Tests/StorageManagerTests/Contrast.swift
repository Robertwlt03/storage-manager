import Foundation

/// The WCAG 2 contrast ratio, computed exactly as the guideline defines it.
enum Contrast {
    private static let flare = 0.05
    private static let redWeight = 0.2126
    private static let greenWeight = 0.7152
    private static let blueWeight = 0.0722
    private static let linearLimit = 0.03928
    private static let linearSlope = 12.92
    private static let gammaOffset = 0.055
    private static let gammaScale = 1.055
    private static let gamma = 2.4
    private static let channelMaximum = 255.0

    static func ratio(_ first: UInt32, _ second: UInt32) -> Double {
        let firstLuminance = relativeLuminance(of: first)
        let secondLuminance = relativeLuminance(of: second)
        let lighter = max(firstLuminance, secondLuminance)
        let darker = min(firstLuminance, secondLuminance)
        return (lighter + flare) / (darker + flare)
    }

    private static func relativeLuminance(of color: UInt32) -> Double {
        let red = linear(channel(color, shift: 16))
        let green = linear(channel(color, shift: 8))
        let blue = linear(channel(color, shift: 0))
        return redWeight * red + greenWeight * green + blueWeight * blue
    }

    private static func channel(_ color: UInt32, shift: UInt32) -> Double {
        Double((color >> shift) & 0xFF) / channelMaximum
    }

    private static func linear(_ channel: Double) -> Double {
        guard channel > linearLimit else { return channel / linearSlope }
        return pow((channel + gammaOffset) / gammaScale, gamma)
    }
}
