import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings
    @AppStorage(SettingsKey.binaryUnits) private var binaryUnits = false
    @AppStorage(SettingsKey.layoutMode) private var layout = LayoutMode.list

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
        } detail: {
            detail
                .id(binaryUnits)  // re-render sizes when the unit setting changes
                .safeAreaInset(edge: .top, spacing: 0) { if model.scanning { UI.scanBanner() } }
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: Loc.searchPrompt.s)
        .searchScopes($model.searchScope) {
            ForEach(SearchScope.allCases) { Text($0.title.s).tag($0) }
        }
        .toolbar {
            if (model.pane ?? .overview).supportsGrid && !model.isSearching {
                ToolbarItem {
                    Picker(Loc.layout.s, selection: $layout) {
                        ForEach(LayoutMode.allCases) { Label($0.title.s, systemImage: $0.symbol).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .help(Loc.layout.s)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(Loc.rescan.s, systemImage: Symbols.rescan) { model.scan() }
                    .disabled(model.scanning)
                    .help(Loc.rescanHelp.s)
            }
            ToolbarItem(placement: .primaryAction) {
                SettingsLink { Label(Loc.settings.s, systemImage: Symbols.settings) }
                    .help(Loc.settings.s)
            }
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
