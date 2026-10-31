import SwiftUI

extension UI {
    /// A button with a text, in one of the `ButtonKind` variants; a destructive one says so in red
    /// while it can be clicked.
    struct ActionButton: View {
        let title: String
        var kind = ButtonKind.normal
        var role: ButtonRole?
        let action: () -> Void
        @Environment(\.isEnabled) private var isEnabled

        init(
            _ title: String, _ kind: ButtonKind = .normal, role: ButtonRole? = nil,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.kind = kind
            self.role = role
            self.action = action
        }

        @ViewBuilder var body: some View {
            let button = Button(title, role: role, action: action).appButton(kind)
            if role == .destructive && isEnabled {
                button.foregroundStyle(.bad)
            } else {
                button
            }
        }
    }

    /// A menu that shows its current choice next to its name. On a page it keeps the width of its
    /// content; in a form (`inForm`) the form places it at the row's right edge.
    struct MenuPicker<Value: Hashable, Items: View>: View {
        let title: TextKey
        @Binding var selection: Value
        var inForm = false
        @ViewBuilder let items: Items

        init(
            _ title: TextKey, selection: Binding<Value>, inForm: Bool = false,
            @ViewBuilder _ items: () -> Items
        ) {
            self.title = title
            _selection = selection
            self.inForm = inForm
            self.items = items()
        }

        var body: some View {
            Picker(selection: $selection) {
                items
            } label: {
                Text(title.translated)
            }
            .pickerStyle(.menu)
            .fixedSize(horizontal: !inForm, vertical: !inForm)
        }
    }

    /// A few choices side by side, without a label.
    struct SegmentPicker<Value: Hashable, Items: View>: View {
        @Binding var selection: Value
        @ViewBuilder let items: Items

        init(selection: Binding<Value>, @ViewBuilder _ items: () -> Items) {
            _selection = selection
            self.items = items()
        }

        var body: some View {
            Picker(selection: $selection) {
                items
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }
}
