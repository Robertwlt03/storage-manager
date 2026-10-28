import SwiftUI

struct ExplorerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.explorerPath) {
            FolderView(node: model.root).navigationDestination(for: Node.self) { FolderView(node: $0) }
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
        EntryTable(entries: Entry.contents(of: node), total: node.bytes)
            .overlay { if node.isVirtual && !model.hasData { UI.notMeasured() } }
            .navigationTitle(node.isVirtual ? Loc.paneExplorer.s : node.displayName)
            .navigationSubtitle(subtitle)
            .toolbar {
                if !node.isVirtual {
                    Button(Loc.showInFinder.s, systemImage: Symbols.finder) { FinderService.reveal(node.path) }
                    Button(Loc.info.s, systemImage: Symbols.info) { info = .folder(node) }
                }
            }
            .sheet(item: $info) { InfoSheet(entry: $0) }
    }

    private var subtitle: String {
        node.isVirtual ? Loc.measuredTotal.f(Fmt.bytes(node.bytes)) : Fmt.joined(Fmt.bytes(node.bytes), Paths.display(node.path))
    }
}
