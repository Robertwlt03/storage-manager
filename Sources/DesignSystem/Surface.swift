import AppKit
import SwiftUI

/// Liquid Glass is available from macOS 26; below that, or when switched off, surfaces fall back to classic cards.
enum Glass {
    static var isAvailable: Bool {
        if #available(macOS 26.0, *) { true } else { false }
    }
}

/// Card background: Liquid Glass or a classic opaque card, chosen by the setting.
private struct SurfaceModifier: ViewModifier {
    @AppStorage(SettingsKey.liquidGlass) private var glass = true
    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(macOS 26.0, *), glass {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(Color(nsColor: .controlBackgroundColor), in: shape)
                .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))
        }
    }
}

/// Button roles with their own colour, so several buttons side by side stay distinguishable.
enum ButtonKind {
    case normal, primary, confirm

    /// Fill behind white text; nil = neutral system button.
    var fill: Tone? {
        switch self {
        case .normal: nil
        case .primary: Theme.primaryFill
        case .confirm: Theme.confirmFill
        }
    }
}

private struct AppButtonModifier: ViewModifier {
    @AppStorage(SettingsKey.liquidGlass) private var glass = true
    let kind: ButtonKind

    func body(content: Content) -> some View {
        if let fill = kind.fill {
            if #available(macOS 26.0, *), glass { content.buttonStyle(.glassProminent).tint(fill.color) }
            else { content.buttonStyle(.borderedProminent).tint(fill.color) }
        } else {
            if #available(macOS 26.0, *), glass { content.buttonStyle(.glass) } else { content.buttonStyle(.bordered) }
        }
    }
}

/// Calm, static page background. With Liquid Glass a light accent tint gives the glass something to refract.
struct Backdrop: View {
    @AppStorage(SettingsKey.liquidGlass) private var glass = true

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            if glass && Glass.isAvailable {
                LinearGradient(colors: [Color.accentColor.opacity(Layout.backdropOpacity), .clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    func surface(radius: CGFloat = Layout.cardRadius) -> some View { modifier(SurfaceModifier(radius: radius)) }
    func appButton(_ kind: ButtonKind = .normal) -> some View { modifier(AppButtonModifier(kind: kind)) }
}
