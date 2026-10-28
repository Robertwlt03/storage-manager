import AppKit
import SwiftUI

/// Gentle animations in one place. They run only when something changes (no endless loops, so no extra energy)
/// and switch off when "Reduce motion" is on in the Accessibility settings.
enum Motion {
    static let duration = 0.35

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

extension View {
    /// Animates this view whenever `value` changes.
    func smoothChanges<V: Equatable>(of value: V) -> some View { animation(Motion.standard, value: value) }

    /// Fades content in and out, the standard transition for appearing views.
    func fadeTransition() -> some View { transition(.opacity) }
}
