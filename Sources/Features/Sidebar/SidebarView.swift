import SwiftUI

/// Built from `Pane` and the mounted volumes, so every page appears here automatically.
struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.pane) {
            Section { ForEach(Pane.main, id: \.self, content: row) }
            Section(Loc.sectionTidy.s) { ForEach(Pane.tidy, id: \.self, content: row) }
            Section(Loc.sectionSystem.s) { ForEach(Pane.system, id: \.self, content: row) }
            // The startup disk is the overview; only other volumes (USB sticks, external drives) get their own page.
            let external = model.volumes.filter { !$0.isRoot }
            if !external.isEmpty {
                Section(Loc.sectionVolumes.s) {
                    ForEach(external) { v in Label(v.name, systemImage: v.symbol).tag(Pane.volume(v.path)) }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { SidebarFooter() }
        .toolbar(removing: .sidebarToggle)  // replaced by `SidebarToggle`, see `AppModel.toggleSidebar`
        .toolbar { ToolbarItem { SidebarToggle() } }
        // A fixed width: with only min and ideal, the column renegotiated its width at the end of the reveal
        // animation, which made the reopening sidebar jump.
        .navigationSplitViewColumnWidth(Layout.sidebarIdeal)
    }

    @AppStorage(SettingsKey.unusedDays) private var unusedDays = CleanConfig.defaultUnusedDays

    /// The apps row shows how many apps were not opened for a while, as a gentle reminder.
    private func row(_ pane: Pane) -> some View {
        Label(pane.title.s, systemImage: pane.symbol)
            .badge(pane == .apps ? model.apps.filter { AppUsageService.isUnused($0, days: unusedDays) }.count : 0)
            .tag(pane)
    }
}


/// The button that shows and hides the sidebar, in the sidebar while it is open and next to the page title
/// while it is closed, like the system's own.
struct SidebarToggle: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let title = model.sidebarVisible ? Loc.hideSidebar.s : Loc.showSidebar.s
        Button { model.toggleSidebar() } label: { Label(title, systemImage: Symbols.sidebar) }
            .help(title)
    }
}
