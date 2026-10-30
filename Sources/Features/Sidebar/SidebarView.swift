import SwiftUI

/// The sidebar column.
struct SidebarView: View {
    var body: some View {
        SidebarList()
            // Replaced by `SidebarToggle`, see `AppModel.toggleSidebar`.
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                // Where Apple puts it: trailing edge of the open sidebar, next to the window
                // buttons when closed.
                ToolbarSpacer(.flexible)
                // Own glass circle, so no empty background stays behind when it moves (see
                // ARCHITECTURE.md).
                ToolbarItem { SidebarToggle().glassCircle() }
                    .sharedBackgroundVisibility(.hidden)
            }
            // Fixed: a flexible width jumped at the end of the reveal animation.
            .navigationSplitViewColumnWidth(Layout.sidebarIdealWidth)
    }
}

/// The pages, built from `Pane` and the mounted volumes so every page appears here automatically,
/// with the scan status below. Used by the sidebar column and by the floating sidebar of narrow
/// windows.
private struct SidebarList: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.unusedDays) private var unusedDays = CleanUpRules.defaultUnusedDays

    var body: some View {
        @Bindable var model = model
        List(selection: $model.pane) {
            Section { ForEach(Pane.main, id: \.self, content: row) }
            Section(TextKey.sectionTidy.translated) { ForEach(Pane.tidy, id: \.self, content: row) }
            Section(TextKey.sectionSystem.translated) {
                ForEach(Pane.system, id: \.self, content: row)
            }
            volumesSection
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) { SidebarFooter() }
    }

    /// The startup disk is the overview; only other volumes (USB sticks, external drives) get their
    /// own page.
    @ViewBuilder private var volumesSection: some View {
        let externalVolumes = model.volumes.filter { volume in !volume.isRoot }
        if !externalVolumes.isEmpty { volumeRows(externalVolumes) }
    }

    private func volumeRows(_ volumes: [VolumeInfo]) -> some View {
        Section(TextKey.sectionVolumes.translated) {
            ForEach(volumes) { volume in
                Label(volume.name, systemImage: volume.symbol).tag(Pane.volume(volume.path))
            }
        }
    }

    /// The apps row shows how many apps were not opened for a while, as a gentle reminder.
    private func row(_ pane: Pane) -> some View {
        Label(pane.title.translated, systemImage: pane.symbol)
            .badge(pane == .apps ? unusedAppCount : 0)
            .tag(pane)
    }

    private var unusedAppCount: Int {
        AppUsageService.unused(model.apps, days: unusedDays).count
    }
}

/// The button that shows and hides the sidebar, placed like Apple's own: at the open sidebar's
/// trailing edge, next to the window buttons while it is closed.
private struct SidebarToggle: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let title =
            model.sidebar.isShown ? TextKey.hideSidebar.translated : TextKey.showSidebar.translated
        Button {
            model.toggleSidebar()
        } label: {
            Label(title, systemImage: Symbols.sidebar)
        }
        .help(title)
    }
}

/// In a window too narrow for sidebar and page side by side, the sidebar floats above the page like
/// a popover and the window keeps its size. Picking a page, clicking beside it, the sidebar button
/// again or Escape closes it.
struct SidebarOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .leading) {
            Theme.clickCatcher.contentShape(Rectangle())
                .onTapGesture { model.closeSidebarOverlay() }
            SidebarList()
                .scrollContentBackground(.hidden)
                .frame(width: Layout.sidebarIdealWidth)
                .surface()
                .padding(Space.small)
        }
    }
}
