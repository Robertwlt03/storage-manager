import SwiftUI

struct ExplorerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.explorerPath) {
            FolderView(node: model.root)
                .navigationDestination(for: Node.self) { node in FolderView(node: node) }
        }
    }
}

/// One folder of the scanned tree; the virtual root lists the measured areas.
private struct FolderView: View {
    let node: Node
    @Environment(AppModel.self) private var model
    @State private var informationEntry: Entry?

    private var entries: [Entry] {
        _ = model.revision
        return Entry.contents(of: node)
    }

    var body: some View {
        EntryBrowser(
            entries: entries, total: node.bytes,
            emptyTitle: TextKey.emptyFolder.translated, contentKey: node.path
        )
        .navigationTitle(node.isVirtual ? TextKey.paneExplorer.translated : node.displayName)
        .navigationSubtitle(subtitle)
        .safeAreaInset(edge: .top, spacing: 0) {
            UI.PageHeader(Pane.explorer.information) { folderActions }
        }
        .sheet(item: $informationEntry) { entry in InformationSheet(entry: entry) }
    }

    @ViewBuilder private var folderActions: some View {
        if !node.isVirtual {
            UI.ActionButton(TextKey.showInFinder.translated) { FinderService.reveal(node.path) }
            UI.ActionButton(TextKey.info.translated) { informationEntry = .folder(node) }
        }
    }

    private var subtitle: String {
        node.isVirtual
            ? TextKey.measuredTotal.translated(with: Format.bytes(node.bytes))
            : Format.joined(Format.bytes(node.bytes), Paths.displayName(node.path))
    }
}
