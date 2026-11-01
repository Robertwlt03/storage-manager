import SwiftUI

/// List, tiles and, on Folders, rings: one switch in the toolbar of every page with layouts.
struct LayoutSwitcher: View {
    let pane: Pane
    @AppStorage(SettingsKey.layoutMode) private var layoutMode = LayoutMode.list
    @AppStorage(SettingsKey.showsRings) private var showsRings = false

    var body: some View {
        UI.SegmentPicker(selection: PageLayout.selection(on: pane, $layoutMode, $showsRings)) {
            ForEach(PageLayout.choices(on: pane)) { layout in
                Label(layout.title.translated, systemImage: layout.symbol).tag(layout)
                    .help(layout.title.translated)
            }
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel(TextKey.layoutSwitch.translated)
    }
}

extension PageLayout {
    /// The layout a page shows, as a choice that stores itself; the switch and the View menu share
    /// it.
    static func selection(
        on pane: Pane?, _ layoutMode: Binding<LayoutMode>, _ showsRings: Binding<Bool>
    ) -> Binding<PageLayout> {
        Binding(
            get: {
                shown(
                    on: pane, layoutMode: layoutMode.wrappedValue,
                    showsRings: showsRings.wrappedValue)
            },
            set: { chosen in
                let stored = chosen.stored(
                    on: pane, layoutMode: layoutMode.wrappedValue,
                    showsRings: showsRings.wrappedValue)
                layoutMode.wrappedValue = stored.layoutMode
                showsRings.wrappedValue = stored.showsRings
            })
    }
}
