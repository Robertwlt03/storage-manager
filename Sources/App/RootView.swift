import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings
    @AppStorage(SettingsKey.binaryUnits) private var binaryUnits = false

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
        } detail: {
            detail.id(binaryUnits)  // re-render sizes when the unit setting changes
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: Loc.searchPrompt.s)
        .searchScopes($model.searchScope) {
            ForEach(SearchScope.allCases) { Text($0.title.s).tag($0) }
        }
        .sheet(isPresented: $model.showAccessSheet) { AccessSheet() }
        .syncPreferences()
        .onAppear {
            if AppSettings.launchSettings { openSettings() }
            model.launch()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in model.refreshVolumes() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)) { _ in model.refreshVolumes() }
    }

    @ViewBuilder private var detail: some View {
        if model.isSearching {
            SearchResultsView()
        } else {
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
    }
}
