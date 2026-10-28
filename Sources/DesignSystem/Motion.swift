import AppKit
import SwiftUI

/// Gentle animations in one place. They run only when something changes (no endless loops, so no extra energy)
/// and switch off when "Reduce motion" is on in the Accessibility settings.
enum Motion {
    static let duration = 0.35
    static let hoverScale = 1.015
    static let hoverTint = 0.06

    static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// For content appearing, pages switching, list and grid swapping.
    static var standard: Animation? { reduced ? nil : .smooth(duration: duration) }

    /// The progress bar glides from one update to the next instead of jumping.
    static var progress: Animation? { reduced ? nil : .linear(duration: ScanConfig.progressInterval) }

    /// Changes model state with the standard animation.
    static func animate(_ changes: () -> Void) {
        withAnimation(standard, changes)
    }
}

/// Clickable tiles lift a little under the mouse. Runs only while hovering, so it costs nothing at rest.
private struct HoverLift: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? Motion.hoverScale : 1)
            .animation(Motion.standard, value: hovering)
            .onHover { hovering = $0 }
    }
}

/// Clickable rows get a soft highlight under the mouse, like lists in macOS.
private struct HoverHighlight: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(Color.primary.opacity(hovering ? Motion.hoverTint : 0),
                        in: RoundedRectangle(cornerRadius: Layout.badgeRadius, style: .continuous))
            .animation(Motion.standard, value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func hoverLift() -> some View { modifier(HoverLift()) }
    func hoverHighlight() -> some View { modifier(HoverHighlight()) }

    /// Charts redraw without animation: Swift Charts crashed while animating between changing datasets during a scan,
    /// and redrawing once is also cheaper.
    func staticChart() -> some View { transaction { $0.animation = nil } }

    /// Animates this view whenever `value` changes.
    func smoothChanges<V: Equatable>(of value: V) -> some View { animation(Motion.standard, value: value) }

    /// Fades content in and out, the standard transition for appearing views.
    func fadeTransition() -> some View { transition(.opacity) }
}
