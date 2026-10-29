import SwiftUI

extension UI {
    /// Icon, title, optional detail, value and, if it leads somewhere, a chevron.
    struct NavRow: View {
        let title: String
        var icon: IconKind?
        var detail: String?
        var value: String?
        var action: (() -> Void)?

        init(
            _ title: String, icon: IconKind? = nil, detail: String? = nil, value: String? = nil,
            action: (() -> Void)? = nil
        ) {
            self.title = title
            self.icon = icon
            self.detail = detail
            self.value = value
            self.action = action
        }

        var body: some View {
            Button {
                action?()
            } label: {
                HStack(spacing: Space.item) {
                    if let icon { Icon(icon) }
                    VStack(alignment: .leading, spacing: Space.hairline) {
                        Text(title)
                        if let detail { Text(detail).textRole(.hint) }
                    }
                    Spacer(minLength: Space.item)
                    if let value { Text(value).textRole(.value).contentTransition(.numericText()) }
                    Chevron().opacity(action == nil ? 0 : 1)
                }
                .contentShape(Rectangle())
                // The highlight reaches a little beyond the row without changing its layout.
                .padding(.horizontal, Space.small).padding(.vertical, Space.extraSmall)
                .modifier(OptionalHover(active: action != nil))
                .padding(.horizontal, -Space.small).padding(.vertical, -Space.extraSmall)
            }
            .appButton(.content)
            .allowsHitTesting(action != nil)  // not .disabled, which would dim the text below 4.5:1
            .accessibilityElement(children: .combine)
        }
    }

    /// A label and its value; a value of nil is still being calculated.
    struct Field: Identifiable {
        let label: String
        let value: String?
        var id: String { label }

        init(_ label: TextKey, _ value: String?) { self.init(label.translated, value) }
        init(_ label: String, _ value: String?) {
            self.label = label
            self.value = value
        }
    }

    /// Label/value rows with dividers; optional fields are passed as nil.
    struct Fields: View {
        let fields: [Field]

        init(_ fields: [Field?]) { self.fields = fields.compactMap { $0 } }

        var body: some View {
            Rows(fields) { field in
                HStack(alignment: .firstTextBaseline, spacing: Space.item) {
                    Text(field.label)
                    Spacer(minLength: Space.item)
                    Text(field.value ?? StandInText.figure).textRole(.value)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                        .calculating(field.value == nil, alignment: .trailing)
                }
            }
        }
    }

    /// A large icon with title and subtitle, at the top of volume cards and sheets.
    struct TitleRow: View {
        let title: String
        let subtitle: String
        let icon: IconKind
        var size = IconSize.large

        init(_ title: String, subtitle: String, icon: IconKind, size: IconSize = .large) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.size = size
        }

        var body: some View {
            HStack(spacing: Space.item) {
                Icon(icon, size: size)
                VStack(alignment: .leading, spacing: Space.hairline) {
                    Text(title).textRole(.title).lineLimit(2)
                    Text(subtitle).foregroundStyle(.muted).lineLimit(2).textSelection(.enabled)
                }
            }
        }
    }
}

/// Only rows that lead somewhere light up under the mouse.
private struct OptionalHover: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.hoverHighlight() } else { content }
    }
}
