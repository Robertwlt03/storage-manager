import AppKit
import SwiftUI

struct RootView: View {
    /// The floating sidebar waits fully outside the window's left edge.
    private static let hiddenSidebarOffset = -(Layout.sidebarIdealWidth + Space.large)

    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var model = model
        NavigationSplitView(columnVisibility: $model.sidebar.visibility) {
            SidebarView()
        } detail: {
            page
        }
        // Replaced by `SidebarToggle`, see `AppModel.toggleSidebar`.
        .toolbar(removing: .sidebarToggle)
        .searchable(
            text: $model.searchText, isPresented: $model.isSearchPresented, placement: .toolbar,
            prompt: TextKey.searchPrompt.translated
        )
        .sheet(isPresented: $model.isShowingAccessSheet) { AccessSheet() }
        .appLocale()
        .onExitCommand(perform: closeSidebarOrSearch)
        .onChange(of: model.pane, leaveSearchAndSidebar)
        .onAppear(perform: start)
        .modifier(SystemEvents(model: model))
    }

    /// The page beside the sidebar; cards are never squeezed, also with the sidebar open.
    private var page: some View {
        detail
            .frame(minWidth: Layout.pageMinimumWidth)
            .overlay(alignment: .leading) { floatingSidebar }
            .smoothChanges(of: model.pane)
            .smoothChanges(of: model.isSearching)
    }

    @ViewBuilder private var detail: some View {
        if model.isSearching {
            SearchResultsView().fadeTransition()
        } else {
            (model.pane ?? .overview).page
                .id(model.pane)
                .fadeTransition()
        }
    }

    /// Slid, never removed or faded (see ARCHITECTURE.md).
    @ViewBuilder private var floatingSidebar: some View {
        if model.sidebar.isWindowNarrow {
            SidebarOverlay()
                .offset(x: model.sidebar.isFloating ? 0 : Self.hiddenSidebarOffset)
                .allowsHitTesting(model.sidebar.isFloating)
                .accessibilityHidden(!model.sidebar.isFloating)
        }
    }

    /// Escape closes the floating sidebar, otherwise it leaves the search.
    private func closeSidebarOrSearch() {
        if model.sidebar.isFloating {
            model.closeSidebarOverlay()
        } else if model.isSearching || model.isSearchPresented {
            model.endSearch()
        }
    }

    /// Picking a page leaves the search and closes the floating sidebar.
    private func leaveSearchAndSidebar() {
        if model.isSearching { model.endSearch() }
        model.closeSidebarOverlay()
    }

    private func start() {
        model.windowResized()
        if AppSettings.opensSettingsAtLaunch { openSettings() }
        model.launch()
        if let reportFolder = AppSettings.uiTestReportFolder {
            Task {
                await UITest.run(model, into: reportFolder)
                NSApp.terminate(nil)
            }
        }
    }
}

/// Follows the window's size and the drives that are connected or ejected.
private struct SystemEvents: ViewModifier {
    let model: AppModel

    func body(content: Content) -> some View {
        content
            .onReceive(windowResizes) { _ in model.windowResized() }
            .onReceive(drivesConnected) { _ in model.refreshVolumes() }
            .onReceive(drivesEjected) { _ in model.refreshVolumes() }
    }

    private var windowResizes: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)
    }

    private var drivesConnected: NotificationCenter.Publisher {
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)
    }

    private var drivesEjected: NotificationCenter.Publisher {
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)
    }
}
