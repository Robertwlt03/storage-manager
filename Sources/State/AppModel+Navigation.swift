import AppKit
import SwiftUI

/// Moving around the app: the sidebar, the window's width, the search and opening what a row
/// shows. These only set the public state in AppModel.swift.
extension AppModel {
    /// Animated by SwiftUI, not AppKit (see ARCHITECTURE.md).
    func toggleSidebar() {
        withAnimation(Motion.standard) { sidebar.toggle() }
    }

    func closeSidebarOverlay() {
        guard sidebar.isFloating else { return }
        withAnimation(Motion.standard) { sidebar.closeFloating() }
    }

    private var mainWindow: NSWindow? {
        NSApp.windows.first { window in window.identifier?.rawValue == WindowID.main }
    }

    /// Reads the width from the window, because SwiftUI's width jumps across the limit for a
    /// moment while the window moves (see ARCHITECTURE.md).
    func windowResized() {
        guard let width = mainWindow?.frame.width else { return }
        sidebar.measure(windowWidth: width)
        withAnimation(Motion.quick) { sidebar.fitToWindow() }
    }

    func endSearch() {
        searchText = ""
        isSearchPresented = false
    }

    func activate(_ entry: Entry) {
        if let node = entry.node {
            open(node)
        } else if let path = entry.path {
            FinderService.reveal(path)
        }
    }

    func open(_ node: Node) {
        explorerPath = node.nodesFromRoot
        endSearch()  // opening a result leaves the search, even when the explorer is already shown
        pane = .explorer
    }
}
