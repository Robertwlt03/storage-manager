import AppKit
import SwiftUI

enum Prefs {
    static let appearance = "appearance"  // 0 system, 1 light, 2 dark
    static let palette = "palette"  // 0 colourful, 1 accent colour, 2 greys
    static let binaryUnits = "binaryUnits"
    static let autoScan = "autoScan"
    static let eco = "eco"
    static let pauseOnLowPower = "pauseOnLowPower"
    static let largeFileMB = "largeFileMB"
    static let extraFolders = "extraFolders"

    static func register() {
        UserDefaults.standard.register(defaults: [autoScan: true, eco: true, pauseOnLowPower: true, largeFileMB: 500])
    }
}

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

    /// Approximations of the system surfaces: content, window, grouped form rows, sidebar.
    static let lightSurfaces: [UInt32] = [0xFFFFFF, 0xF5F5F7, 0xECECEC, 0xE3E3E3]
    static let darkSurfaces: [UInt32] = [0x1E1E1E, 0x262626, 0x2D2D2D, 0x323232, 0x3A3A3A]

    static let colourful: [Color] = [.blue, .purple, .pink, .orange, .yellow, .green, .teal, .indigo, .red, .brown, .mint, .cyan,
                                     .gray, .blue, .purple, .secondary]

    static func color(_ index: Int, palette: Int) -> Color {
        switch palette {
        case 1: Color.accentColor.opacity(1 - Double(index % 7) * 0.11)
        case 2: Color(white: 0.25 + Double(index % 8) * 0.08)
        default: colourful[index % colourful.count]
        }
    }

    /// Prints every text/surface pair in both modes; false if one is below 4.5:1 (WCAG AA).
    static func checkContrast() -> Bool {
        let texts = [("Gedämpft", muted), ("Grün", good), ("Orange", warn), ("Rot", bad)]
        var ok = true
        for (dark, surfaces) in [(false, lightSurfaces), (true, darkSurfaces)] {
            for (name, t) in texts {
                for s in surfaces {
                    let r = ratio(dark ? t.dark : t.light, s)
                    ok = ok && r >= 4.5
                    print("\(r >= 4.5 ? "ok  " : "FAIL") \(String(format: "%5.2f", r)):1  \(name) auf #\(String(s, radix: 16)) (\(dark ? "dunkel" : "hell"))")
                }
            }
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

/// App icon for build.sh: 1024 px canvas, 824 px rounded square as in Apple's macOS icon grid.
struct AppIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.62, blue: 1.0), Color(red: 0.12, green: 0.32, blue: 0.86)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
            ZStack {
                Circle().stroke(.white.opacity(0.22), lineWidth: 96)
                ring(0, 0.46, opacity: 1)
                ring(0.47, 0.70, opacity: 0.78)
                ring(0.71, 0.84, opacity: 0.55)
            }
            .frame(width: 440, height: 440)
        }
        .frame(width: 1024, height: 1024)
    }

    private func ring(_ from: Double, _ to: Double, opacity: Double) -> some View {
        Circle().trim(from: from, to: to)
            .stroke(.white.opacity(opacity), style: StrokeStyle(lineWidth: 96, lineCap: .butt))
            .rotationEffect(.degrees(-90))
    }
}
