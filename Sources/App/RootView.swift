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
                .smoothChanges(of: model.pane)
                .smoothChanges(of: model.isSearching)
        }
        .toolbar(removing: .sidebarToggle)  // replaced by `SidebarToggle`, see `AppModel.toggleSidebar`
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)) { _ in model.windowResized() }
        .searchable(text: $model.searchText, isPresented: $model.searchPresented, placement: .toolbar, prompt: Loc.searchPrompt.s)
        .sheet(isPresented: $model.showAccessSheet) { AccessSheet() }
        .syncPreferences()
        .onExitCommand { if model.isSearching || model.searchPresented { model.endSearch() } }  // Escape leaves the search
        .onChange(of: model.pane) { if model.isSearching { model.endSearch() } }  // picking a page leaves it too
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
