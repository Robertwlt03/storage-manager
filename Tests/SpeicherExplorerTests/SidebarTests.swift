import SwiftUI
import Testing

@testable import SpeicherExplorer

/// The sidebar's rules, like Mail: a narrow window closes it, a wide one brings it back unless the
/// user closed it, and in a narrow window the button lets it float above the page.
@Suite("Sidebar")
struct SidebarTests {
    private static let wide = Layout.sidebarCollapseWidth + 200
    private static let narrow = Layout.sidebarCollapseWidth - 200

    private static func resized(_ sidebar: inout SidebarState, to width: CGFloat) {
        sidebar.measure(windowWidth: width)
        sidebar.fitToWindow()
    }

    @Test("A narrow window closes the sidebar, a wide one brings it back")
    func followsTheWindow() {
        var sidebar = SidebarState()
        Self.resized(&sidebar, to: Self.narrow)
        #expect(!sidebar.isVisible)
        #expect(sidebar.isWindowNarrow)
        Self.resized(&sidebar, to: Self.wide)
        #expect(sidebar.isVisible)
    }

    @Test("A sidebar the user closed stays closed when the window grows")
    func keepsTheUsersChoice() {
        var sidebar = SidebarState()
        Self.resized(&sidebar, to: Self.wide)
        sidebar.toggle()
        #expect(!sidebar.isShown)
        Self.resized(&sidebar, to: Self.narrow)
        Self.resized(&sidebar, to: Self.wide)
        #expect(!sidebar.isVisible)
        sidebar.toggle()
        #expect(sidebar.isVisible)
    }

    @Test("In a narrow window the button lets the sidebar float, and growing ends the floating")
    func floatsInANarrowWindow() {
        var sidebar = SidebarState()
        Self.resized(&sidebar, to: Self.narrow)
        sidebar.toggle()
        #expect(sidebar.isFloating)
        #expect(sidebar.isShown && !sidebar.isVisible)
        sidebar.closeFloating()
        #expect(!sidebar.isShown)
        sidebar.toggle()
        Self.resized(&sidebar, to: Self.wide)
        #expect(!sidebar.isFloating)
        #expect(sidebar.isVisible)
    }

    @Test("When macOS closes the sidebar on its own, the next resize in a wide window reopens it")
    func repairsWhatMacOSDid() {
        var sidebar = SidebarState()
        Self.resized(&sidebar, to: Self.wide)
        sidebar.visibility = .detailOnly
        Self.resized(&sidebar, to: Self.wide)
        #expect(sidebar.isVisible)
    }
}
