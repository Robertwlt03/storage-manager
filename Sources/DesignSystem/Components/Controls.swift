import SwiftUI

extension UI {
    /// A button with a text, in one of the `ButtonKind` variants.
    struct ActionButton: View {
        let title: String
        var kind = ButtonKind.normal
        var role: ButtonRole?
        let action: () -> Void

        init(_ title: String, _ kind: ButtonKind = .normal, role: ButtonRole? = nil, action: @escaping () -> Void) {
            self.title = title
            self.kind = kind
            self.role = role
            self.action = action
        }

        var body: some View { Button(title, role: role, action: action).appButton(kind) }
    }

    /// A menu that shows its current choice next to its name.
    struct MenuPicker<Value: Hashable, Items: View>: View {
        let title: Loc
        @Binding var selection: Value
        @ViewBuilder let items: Items

        init(_ title: Loc, selection: Binding<Value>, @ViewBuilder _ items: () -> Items) {
            self.title = title
            _selection = selection
            self.items = items()
        }

        var body: some View {
            Picker(selection: $selection, content: { items }) { Text(title.s) }
                .pickerStyle(.menu)
                .fixedSize()
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
            Picker(selection: $selection, content: { items }) { EmptyView() }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
        }
    }
}
