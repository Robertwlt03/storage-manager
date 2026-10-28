import SwiftUI

/// The sidebar column with its toolbar button.
struct SidebarView: View {
    var body: some View {
        SidebarList()
            .toolbar(removing: .sidebarToggle)  // replaced by `SidebarToggle`, see `AppModel.toggleSidebar`
            .toolbar {
                // A flexible spacer first puts the button at the sidebar's trailing edge, where the system keeps its own.
                if #available(macOS 26.0, *) { ToolbarSpacer(.flexible) }
                ToolbarItem { SidebarToggle() }
            }
            // A fixed width: with only min and ideal, the column renegotiated its width at the end of the reveal
            // animation, which made the reopening sidebar jump.
            .navigationSplitViewColumnWidth(Layout.sidebarIdeal)
    }
}

/// The pages, built from `Pane` and the mounted volumes so every page appears here automatically, with the scan
/// status below. Used by the sidebar column and by the floating sidebar of narrow windows.
struct SidebarList: View {
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
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) { SidebarFooter() }
    }

    @AppStorage(SettingsKey.unusedDays) private var unusedDays = CleanConfig.defaultUnusedDays

    /// The apps row shows how many apps were not opened for a while, as a gentle reminder.
    private func row(_ pane: Pane) -> some View {
        Label(pane.title.s, systemImage: pane.symbol)
            .badge(pane == .apps ? model.apps.filter { AppUsageService.isUnused($0, days: unusedDays) }.count : 0)
            .tag(pane)
    }
}


/// The button that shows and hides the sidebar, next to the window buttons like the system's own. It belongs to the
/// sidebar's toolbar, which macOS keeps visible while the sidebar is closed, so one button serves both states.
struct SidebarToggle: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let title = model.sidebarShown ? Loc.hideSidebar.s : Loc.showSidebar.s
        Button { model.toggleSidebar() } label: { Label(title, systemImage: Symbols.sidebar) }
            .help(title)
    }
}

/// In a window too narrow for sidebar and page side by side, the sidebar floats above the page like a popover and
/// the window keeps its size. Picking a page, clicking beside it, the sidebar button again or Escape closes it.
struct SidebarOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .leading) {
            Color.clear.contentShape(Rectangle()).onTapGesture { model.closeSidebarOverlay() }
            SidebarList()
                .scrollContentBackground(.hidden)
                .frame(width: Layout.sidebarIdeal)
                .surface()
                .padding(Space.s)
        }
    }
}
