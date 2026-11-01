import SwiftUI

/// The question before a file goes to the Trash, asked once for the whole window, and what to say
/// when macOS refuses.
struct FileTrash: ViewModifier {
    @Environment(AppModel.self) private var model
    @State private var failedName: String?

    func body(content: Content) -> some View {
        @Bindable var model = model
        content
            .confirmRemoval(
                TextKey.trashTitle.translated(with: model.fileToTrash?.name ?? ""),
                item: $model.fileToTrash, button: .moveToTrash, message: .trashFileMessage,
                action: moveToTrash
            )
            .alert(
                TextKey.trashFailed.translated(with: failedName ?? ""),
                isPresented: Binding(get: { failedName != nil }, set: { _ in failedName = nil })
            ) {}
    }

    private func moveToTrash(_ entry: Entry) {
        guard let path = entry.path else { return }
        do { try model.moveToTrash(path) } catch { failedName = entry.name }
    }
}
