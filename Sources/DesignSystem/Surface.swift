import AppKit
import SwiftUI

/// Card background. On macOS 26 and later it is Liquid Glass, which follows the system's own
/// setting (clear or tinted, System Settings › Appearance); earlier systems get a classic card.
private struct SurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
        content.glassEffect(.regular, in: shape)
    }
}

/// Button roles with their own color, so several buttons side by side stay distinguishable.
/// `quiet` is a bare symbol button (sidebar footer, info button); `content` makes a whole row, tile
/// or legend entry clickable without drawing a button around it.
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
        switch kind {
        case .quiet: content.buttonStyle(.borderless)
        case .content: content.buttonStyle(.plain)
        case .normal, .primary, .confirm: framed(content)
        }
    }

    /// Liquid Glass, tinted when the button has a fill of its own.
    @ViewBuilder private func framed(_ content: Content) -> some View {
        if let fill = kind.fill {
            content.buttonStyle(.glassProminent).tint(fill.color)
        } else {
            content.buttonStyle(.glass)
        }
    }
}

/// Plain window background behind pages, like other Apple apps.
struct Backdrop: View {
    var body: some View { Theme.windowBackground.ignoresSafeArea() }
}

extension View {
    func surface() -> some View { modifier(SurfaceModifier()) }
    /// A round glass button for the toolbar, drawn by the button itself (see ARCHITECTURE.md).
    func glassCircle() -> some View { buttonStyle(.glass).buttonBorderShape(.circle) }
    func appButton(_ kind: ButtonKind = .normal) -> some View {
        modifier(AppButtonModifier(kind: kind))
    }
}
