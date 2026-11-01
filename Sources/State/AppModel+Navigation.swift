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

    /// Double-click on a row or tile: folders open in the explorer, files show in Finder.
    func activate(_ entry: Entry) {
        if let node = entry.node {
            open(node)
        } else if let path = entry.path {
            FinderService.reveal(path)
        }
    }

    /// A folder inside the shown one goes on top of the path, so going back returns to what was
    /// shown, a category's folders too; anything else opens with the path from its scan root.
    func open(_ node: Node) {
        if let shown = explorerPath.last, shown.children.contains(node) {
            explorerPath.append(node)
        } else {
            explorerPath = node.isGroup ? [node] : node.nodesFromRoot
        }
        endSearch()  // opening a result leaves the search, even when the explorer is already shown
        pane = .explorer
    }

    /// A click on a category: its folders, sized like the category (CategoryService.folder).
    func open(_ category: Category) {
        guard let folder = CategoryService.folder(of: category) else { return }
        explorerPath = []
        open(folder)
        shownCategory = category.kind
    }

    /// A category's folders are copies that keep their old sizes after the tree changes, so its
    /// view starts again from the new tree; going elsewhere forgets the category.
    func refreshShownCategory() {
        let shownCopies = explorerPath.contains { node in node.isGroup || !root.holds(node) }
        guard let kind = shownCategory, shownCopies else {
            shownCategory = nil
            return
        }
        let category = categories.first { category in category.kind == kind }
        let folder = category.flatMap(CategoryService.folder(of:))
        explorerPath = folder.map { folder in [folder] } ?? []
    }
}
