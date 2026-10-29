import SwiftUI

/// Bottom of the sidebar, always in the same place: a quiet scan status (details on click)
/// and the app-wide controls – list or grid, rescan and settings.
struct SidebarFooter: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.layoutMode) private var layout = LayoutMode.list
    @State private var showDetails = false
    @State private var scanStarts = 0  // turns the rescan symbol once when a scan starts (button or ⌘R; not at launch)

    var body: some View {
        VStack(alignment: .leading, spacing: Space.row) {
            Button { showDetails.toggle() } label: { status }
                .appButton(.content)
                .help(Loc.scanDetails.s)
                .popover(isPresented: $showDetails, arrowEdge: .trailing) { ScanDetails() }
            if model.scanning {
                ProgressView(value: model.scanFraction).progressViewStyle(.linear).controlSize(.small)
                    .animation(Motion.quick, value: model.scanFraction)
                    .fadeTransition()
            }
            Divider()
            HStack(spacing: Space.m) {
                // One quiet button like the two next to it; the symbol shows what a click switches to.
                Button { layout = layout == .list ? .grid : .list } label: {
                    UI.Icon(.symbol(layout == .list ? Symbols.grid : Symbols.list), size: .small).contentTransition(.symbolEffect(.replace))
                }
                .appButton(.quiet)
                .disabled(!(model.pane ?? .overview).supportsGrid || model.isSearching)
                .help(layout == .list ? Loc.layoutGrid.s : Loc.layoutList.s)
                .accessibilityLabel(layout == .list ? Loc.layoutGrid.s : Loc.layoutList.s)
                Spacer()
                Button { model.scan() } label: { UI.Icon(.symbol(Symbols.rescan), size: .small).turnOnce(value: scanStarts) }
                    .appButton(.quiet)
                    .disabled(model.scanning)
                    .help(Loc.rescanHelp.s)
                SettingsLink { UI.Icon(.symbol(Symbols.settings), size: .small) }
                    .appButton(.quiet)
                    .help(Loc.settings.s)
            }
        }
        .padding(Space.item)
        .onChange(of: model.scanning) { if model.scanning { scanStarts += 1 } }
    }

    /// One short line: spinner and percent while scanning, otherwise when it was measured.
    private var status: some View {
        HStack(spacing: Space.s) {
            if model.scanning {
                // No spinner here: the progress bar right below already moves, and Apple prefers one determinate
                // indicator over a second endless one.
                UI.Icon(.symbol(Symbols.measure), size: .small).foregroundStyle(.tint)
                Text(Loc.scanningPercent.f(Fmt.percent(model.scanFraction))).monospacedDigit()
                    .contentTransition(.numericText(value: model.scanFraction))
                    .animation(Motion.quick, value: model.scanFraction)
            } else if let t = model.lastScan {
                UI.Icon(.symbol(model.unreadable > 0 && !model.hasFullDiskAccess ? Symbols.warning : Symbols.success),
                         size: .small)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: t)  // a small nod when a scan has finished
                    .foregroundStyle(model.unreadable > 0 && !model.hasFullDiskAccess ? .warn : .good)
                Text(Loc.measuredAt.f(Fmt.time(t)))
            } else {
                UI.Icon(.symbol(Symbols.measure), size: .small).foregroundStyle(.muted)
                Text(Loc.notMeasuredTitle.s)
            }
            Spacer(minLength: 0)
            UI.Icon(.symbol(Symbols.info), size: .small).foregroundStyle(.muted)
        }
        .font(.callout)
        .contentShape(Rectangle())
    }
}

/// Everything about the scan, shown only when asked for.
struct ScanDetails: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Space.item) {
            Text(model.scanning ? Loc.scanningTitle.s : Loc.scanDetails.s).textRole(.section)
            if model.scanning {
                ProgressView(value: model.scanFraction).progressViewStyle(.linear)
                    .animation(Motion.quick, value: model.scanFraction)
                UI.Fields([UI.Field(.scanProgress, Fmt.percent(model.scanFraction)),
                           UI.Field(.scanArea, Loc.scanningArea.f(Fmt.count(model.scanStep.index), Fmt.count(model.scanStep.count),
                                                                      Paths.display(model.scanStep.path))),
                           UI.Field(.files, Loc.filesAndSize.f(Fmt.count(model.progress.files), Fmt.bytes(model.progress.bytes)))])
                UI.ActionButton(Loc.cancelScan.s) { model.cancelScan() }
            } else {
                UI.Fields([model.lastScan.map { UI.Field(.scanFinished, Fmt.time($0)) },
                           UI.Field(.files, Loc.filesAndSize.f(Fmt.count(model.root.fileCount), Fmt.bytes(model.root.bytes))),
                           UI.Field(.fullDiskAccess, model.hasFullDiskAccess ? Loc.accessGranted.s : Loc.accessMissingShort.s)])
                if model.unreadable > 0 && !model.hasFullDiskAccess {
                    UI.Note(Loc.unreadable.f(Fmt.count(model.unreadable)))
                    UI.ActionButton(Loc.accessOpenSettings.s, .primary) { FinderService.openFullDiskAccessSettings() }
                }
                UI.ActionButton(model.lastScan == nil ? Loc.scanNow.s : Loc.rescan.s) { model.scan() }
            }
        }
        .padding(Space.card)
        .frame(width: Layout.popoverWidth)
    }
}
