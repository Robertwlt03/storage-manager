import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
        } detail: {
            detail
                .smoothChanges(of: model.pane)
                .smoothChanges(of: model.isSearching)
        }
        .searchable(text: $model.searchText, isPresented: $model.searchPresented, placement: .toolbar, prompt: Loc.searchPrompt.s)
        .searchScopes($model.searchScope) {
            ForEach(SearchScope.allCases) { Text($0.title.s).tag($0) }
        }
        .sheet(isPresented: $model.showAccessSheet) { AccessSheet() }
        .syncPreferences()
        .onExitCommand { if model.isSearching { model.endSearch() } }  // Escape leaves the search
        .onChange(of: model.pane) { if model.isSearching { model.endSearch() } }  // picking a page leaves it too
        .onAppear {
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
            case .statistics: StatisticsView()
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
