import SwiftUI

/// The widget's own few looks: it cannot reach the app's design system, so its text roles and the
/// background of its picture live here, as the app's live in Sources/DesignSystem.
enum WidgetTextRole {
    case label, figure, note
}

extension View {
    @ViewBuilder func widgetText(_ role: WidgetTextRole) -> some View {
        switch role {
        case .label: font(.caption).foregroundStyle(.secondary)
        case .figure: font(.title).bold()
        case .note: font(.caption2).foregroundStyle(.secondary)
        }
    }

    /// The plain background the widget's picture is drawn on, as macOS draws the widget's own.
    func widgetPictureBackground() -> some View { background(.background) }
}
