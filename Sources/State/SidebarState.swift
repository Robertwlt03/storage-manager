import SwiftUI

/// The sidebar's rules, without window or animation, so tests can check them (see ARCHITECTURE.md):
/// a narrow window closes the sidebar and the sidebar button lets it float above the page; a wide
/// window brings it back unless the user closed it, like Mail.
struct SidebarState {
    var visibility = NavigationSplitViewVisibility.all
    /// In a narrow window the sidebar floats above the page for a moment instead of taking room
    /// beside it.
    private(set) var isFloating = false
    private(set) var isWindowNarrow = false
    /// The user's choice; only they open it again.
    private var wasClosedByUser = false

    var isVisible: Bool { visibility != .detailOnly }
    var isShown: Bool { isVisible || isFloating }

    /// What the sidebar button and ⌃⌘S do.
    mutating func toggle() {
        if isWindowNarrow && !isVisible {
            isFloating.toggle()
            return
        }
        wasClosedByUser = isVisible  // closing it now, or opening it again
        visibility = isVisible ? .detailOnly : .all
    }

    /// Picking a page, clicking beside the floating sidebar or pressing Escape closes it.
    mutating func closeFloating() { isFloating = false }

    /// Notes the window's width; kept apart from `fitToWindow`, because the floating sidebar's
    /// container must appear without animation.
    mutating func measure(windowWidth: CGFloat) {
        isWindowNarrow = windowWidth < Layout.sidebarCollapseWidth
    }

    /// Compares wanted and actual state after every resize, because macOS also closes the sidebar
    /// on its own at the edge.
    mutating func fitToWindow() {
        if isWindowNarrow && isVisible {
            visibility = .detailOnly
        } else if shouldComeBack {
            wasClosedByUser = false
            isFloating = false
            visibility = .all
        }
    }

    private var shouldComeBack: Bool {
        !isWindowNarrow && !isVisible && (!wasClosedByUser || isFloating)
    }
}
