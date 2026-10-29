import AppKit
import SwiftUI

/// Card background. On macOS 26 and later it is Liquid Glass, which follows the system's own setting
/// (clear or tinted, System Settings › Appearance); earlier systems get a classic card.
private struct SurfaceModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(Color(nsColor: .controlBackgroundColor), in: shape)
                .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))
        }
    }
}

/// Button roles with their own colour, so several buttons side by side stay distinguishable.
/// `quiet` is a bare symbol button (sidebar footer, info button); `content` makes a whole row, tile or legend entry
/// clickable without drawing a button around it.
enum ButtonKind {
    case normal, primary, confirm, quiet, content

    /// Fill behind white text; nil = no fill.
    var fill: Tone? {
        switch self {
        case .normal, .quiet, .content: nil
        case .primary: Theme.primaryFill
        case .confirm: Theme.confirmFill
        }
    }
}

private struct AppButtonModifier: ViewModifier {
    let kind: ButtonKind

    func body(content: Content) -> some View {
        if kind == .quiet {
            content.buttonStyle(.borderless)
        } else if kind == .content {
            content.buttonStyle(.plain)
        } else if let fill = kind.fill {
            if #available(macOS 26.0, *) {
                content.buttonStyle(.glassProminent).tint(fill.color)
            } else {
                content.buttonStyle(.borderedProminent).tint(fill.color)
            }
        } else {
            if #available(macOS 26.0, *) {
                content.buttonStyle(.glass)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}

/// Plain window background behind pages, like other Apple apps.
struct Backdrop: View {
    var body: some View { Color(nsColor: .windowBackgroundColor).ignoresSafeArea() }
}

extension View {
    func surface(radius: CGFloat = Layout.cardRadius) -> some View {
        modifier(SurfaceModifier(radius: radius))
    }
    func appButton(_ kind: ButtonKind = .normal) -> some View {
        modifier(AppButtonModifier(kind: kind))
    }
}
