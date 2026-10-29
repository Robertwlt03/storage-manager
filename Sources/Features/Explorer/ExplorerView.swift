import SwiftUI

struct ExplorerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.explorerPath) {
            FolderView(node: model.root)
                .navigationDestination(for: Node.self) { FolderView(node: $0) }
        }
    }
}

/// One folder of the scanned tree; the virtual root lists the measured areas.
struct FolderView: View {
    let node: Node
    @Environment(AppModel.self) private var model
    @State private var info: Entry?

    var body: some View {
        let _ = model.revision
        EntryBrowser(
            entries: Entry.contents(of: node), total: node.bytes,
            emptyTitle: TextKey.emptyFolder.translated, contentKey: node.path
        )
        .navigationTitle(node.isVirtual ? TextKey.paneExplorer.translated : node.displayName)
        .navigationSubtitle(subtitle)
        .safeAreaInset(edge: .top, spacing: 0) {
            UI.PageHeader(Pane.explorer.info) {
                if !node.isVirtual {
                    UI.ActionButton(TextKey.showInFinder.translated) {
                        FinderService.reveal(node.path)
                    }
                    UI.ActionButton(TextKey.info.translated) { info = .folder(node) }
                }
            }
        }
        .sheet(item: $info) { InfoSheet(entry: $0) }
    }

    private var subtitle: String {
        node.isVirtual
            ? TextKey.measuredTotal.translated(with: Format.bytes(node.bytes))
            : Format.joined(Format.bytes(node.bytes), Paths.display(node.path))
    }
}
