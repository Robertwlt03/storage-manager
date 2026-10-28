import SwiftUI

/// Built from `Pane` and the mounted volumes, so every page appears here automatically.
struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.pane) {
            Section { ForEach(Pane.main, id: \.self, content: row) }
            Section(Loc.sectionSystem.s) { ForEach(Pane.system, id: \.self, content: row) }
            Section(Loc.sectionVolumes.s) {
                ForEach(model.volumes) { v in Label(v.name, systemImage: v.symbol).tag(Pane.volume(v.path)) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { ScanStatusView() }
        .navigationSplitViewColumnWidth(min: Layout.sidebarMin, ideal: Layout.sidebarIdeal)
    }

    private func row(_ pane: Pane) -> some View {
        Label(pane.title.s, systemImage: pane.symbol).tag(pane)
    }
}

/// Footer of the sidebar: progress while scanning, the result afterwards and a hint about unreadable folders.
struct ScanStatusView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.scanning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(Loc.scanning.s)
                    Spacer()
                    Button(Loc.cancel.s) { model.cancelScan() }.buttonStyle(.link)
                }
                summary(model.progress.files, model.progress.bytes)
            } else if let t = model.lastScan {
                Text(Loc.measuredAt.f(Fmt.time(t))).font(.callout)
                summary(model.root.fileCount, model.root.bytes)
            } else {
                UI.button(Loc.scanNow.s) { model.scan() }
            }
            if model.unreadable > 0 && !model.scanning && !model.hasFullDiskAccess {
                Button(action: FinderService.openFullDiskAccessSettings) {
                    Text(Loc.unreadable.f(Fmt.count(model.unreadable)))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.link)
                .font(.callout)
                .help(Loc.unreadableHelp.s)
            }
        }
        .padding(Layout.rowSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summary(_ files: Int, _ bytes: Int64) -> some View {
        Text(Loc.filesAndSize.f(Fmt.count(files), Fmt.bytes(bytes))).font(.callout).monospacedDigit().foregroundStyle(.muted)
    }
}
