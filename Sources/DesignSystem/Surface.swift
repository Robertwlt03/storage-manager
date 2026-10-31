import AppKit
import SwiftUI

/// Card background: Liquid Glass, which follows the system's own setting (clear or tinted, System
/// Settings › Appearance).
private struct SurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
        content.glassEffect(.regular, in: shape)
    }
}

/// What a button is for, and with it its look and size, so the same kind of action looks the same
/// on every page. `primary` is the one prominent action of a page or sheet, `normal` every other
/// action in a header, a sheet or below a card, and `inline` the small buttons inside rows and
/// cards. A `UI.ActionButton` with `role: .destructive` shows its text in red; it is never the
/// primary one, whose fill would swallow the red.
/// `quiet` is a bare symbol button (sidebar footer, information button); `content` makes a whole
/// row, tile or legend entry clickable without drawing a button around it.
enum ButtonKind {
    case normal, primary, inline, quiet, content

    /// The size of a framed kind; page actions share one, so a header and its sheet line up.
    var size: ControlSize {
        self == .inline ? .small : .large
    }
}

private struct AppButtonModifier: ViewModifier {
    let kind: ButtonKind

    func body(content: Content) -> some View {
        switch kind {
        case .quiet: content.buttonStyle(.borderless)
        case .content: content.buttonStyle(.plain)
        case .primary:
            content.buttonStyle(.glassProminent).tint(Theme.primaryFill.color)
                .controlSize(kind.size)
        case .normal, .inline: content.buttonStyle(.glass).controlSize(kind.size)
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
