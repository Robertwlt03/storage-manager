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
                .buttonStyle(.plain)
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
                    Image(systemName: layout == .list ? Symbols.grid : Symbols.list).smallIcon().contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderless)
                .disabled(!(model.pane ?? .overview).supportsGrid || model.isSearching)
                .help(layout == .list ? Loc.layoutGrid.s : Loc.layoutList.s)
                .accessibilityLabel(layout == .list ? Loc.layoutGrid.s : Loc.layoutList.s)
                Spacer()
                Button { model.scan() } label: { Image(systemName: Symbols.rescan).smallIcon().turnOnce(value: scanStarts) }
                    .buttonStyle(.borderless)
                    .disabled(model.scanning)
                    .help(Loc.rescanHelp.s)
                SettingsLink { Image(systemName: Symbols.settings).smallIcon() }
                    .buttonStyle(.borderless)
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
                Image(systemName: Symbols.measure).smallIcon().foregroundStyle(.tint)
                Text(Loc.scanningPercent.f(Fmt.percent(model.scanFraction))).monospacedDigit()
                    .contentTransition(.numericText(value: model.scanFraction))
                    .animation(Motion.quick, value: model.scanFraction)
            } else if let t = model.lastScan {
                Image(systemName: model.unreadable > 0 && !model.hasFullDiskAccess ? Symbols.warning : Symbols.success)
                    .smallIcon()
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: t)  // a small nod when a scan has finished
                    .foregroundStyle(model.unreadable > 0 && !model.hasFullDiskAccess ? .warn : .good)
                Text(Loc.measuredAt.f(Fmt.time(t)))
            } else {
                Image(systemName: Symbols.measure).smallIcon().foregroundStyle(.muted)
                Text(Loc.notMeasuredTitle.s)
            }
            Spacer(minLength: 0)
            Image(systemName: Symbols.info).smallIcon().foregroundStyle(.muted)
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
            Text(model.scanning ? Loc.scanningTitle.s : Loc.scanDetails.s).font(.headline)
            if model.scanning {
                ProgressView(value: model.scanFraction).progressViewStyle(.linear)
                    .animation(Motion.quick, value: model.scanFraction)
                UI.fields([FieldItem(.scanProgress, Fmt.percent(model.scanFraction)),
                           FieldItem(.scanArea, Loc.scanningArea.f(Fmt.count(model.scanStep.index), Fmt.count(model.scanStep.count),
                                                                      Paths.display(model.scanStep.path))),
                           FieldItem(.files, Loc.filesAndSize.f(Fmt.count(model.progress.files), Fmt.bytes(model.progress.bytes)))])
                UI.button(Loc.cancelScan.s) { model.cancelScan() }
            } else {
                UI.fields([model.lastScan.map { FieldItem(.scanFinished, Fmt.time($0)) },
                           FieldItem(.files, Loc.filesAndSize.f(Fmt.count(model.root.fileCount), Fmt.bytes(model.root.bytes))),
                           FieldItem(.fullDiskAccess, model.hasFullDiskAccess ? Loc.accessGranted.s : Loc.accessMissingShort.s)])
                if model.unreadable > 0 && !model.hasFullDiskAccess {
                    UI.note(Loc.unreadable.f(Fmt.count(model.unreadable)))
                    UI.button(Loc.accessOpenSettings.s, .primary) { FinderService.openFullDiskAccessSettings() }
                }
                UI.button(model.lastScan == nil ? Loc.scanNow.s : Loc.rescan.s) { model.scan() }
            }
        }
        .padding(Space.card)
        .frame(width: Layout.popoverWidth)
    }
}
