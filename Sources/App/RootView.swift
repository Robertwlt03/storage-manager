import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var model = model
        NavigationSplitView(columnVisibility: $model.columns) {
            SidebarView()
        } detail: {
            detail
                .frame(minWidth: Layout.pageMinWidth)  // cards are never squeezed, also with the sidebar open
                .overlay(alignment: .leading) {
                    // Always there in narrow windows and only slid in and out: removing it closed abruptly, because
                    // the list inside (an AppKit table) left at once instead of taking part in the transition.
                    if model.windowNarrow {
                        SidebarOverlay()
                            .offset(x: model.sidebarOverlay ? 0 : -(Layout.sidebarIdeal + Space.l))
                            .opacity(model.sidebarOverlay ? 1 : 0)
                            .allowsHitTesting(model.sidebarOverlay)
                            .accessibilityHidden(!model.sidebarOverlay)
                    }
                }
                .smoothChanges(of: model.pane)
                .smoothChanges(of: model.isSearching)
        }
        .toolbar(removing: .sidebarToggle)  // replaced by `SidebarToggle`, see `AppModel.toggleSidebar`
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)) { _ in model.windowResized() }
        .searchable(text: $model.searchText, isPresented: $model.searchPresented, placement: .toolbar, prompt: Loc.searchPrompt.s)
        .sheet(isPresented: $model.showAccessSheet) { AccessSheet() }
        .syncPreferences()
        .onExitCommand {  // Escape closes the floating sidebar, otherwise it leaves the search
            if model.sidebarOverlay { model.closeSidebarOverlay() } else if model.isSearching || model.searchPresented { model.endSearch() }
        }
        .onChange(of: model.pane) {  // picking a page leaves the search and closes the floating sidebar
            if model.isSearching { model.endSearch() }
            model.closeSidebarOverlay()
        }
        .onAppear {
            model.windowResized()
            if AppSettings.launchSettings { openSettings() }
            model.launch()
            if let dir = AppSettings.launchUITest {
                Task {
                    await UITest.run(model, into: dir)
                    NSApp.terminate(nil)
                }
            }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in model.refreshVolumes() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)) { _ in model.refreshVolumes() }
    }

    @ViewBuilder private var detail: some View {
        if model.isSearching {
            SearchResultsView().fadeTransition()
        } else {
            Group {
                switch model.pane ?? .overview {
            case .overview: OverviewView()
            case .cleaner: CleanerView()
            case .apps: UnusedAppsView()
            case .explorer: ExplorerView()
            case .largeFiles: LargeFilesView()
            case .temp: TempView()
            case .copies: CopiesView()
            case .volume(let path): VolumeView(path: path)
                }
            }
            .id(model.pane)
            .fadeTransition()
        }
    }
}
