import SwiftUI

/// Bottom of the sidebar, always in the same place: a quiet scan status (details on click)
/// and the app-wide controls – list or grid, rescan and settings.
struct SidebarFooter: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.layoutMode) private var layout = LayoutMode.list
    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.rowPadding) {
            Button { showDetails.toggle() } label: { status }
                .buttonStyle(.plain)
                .help(Loc.scanDetails.s)
                .popover(isPresented: $showDetails, arrowEdge: .trailing) { ScanDetails() }
            if model.scanning {
                ProgressView(value: model.scanFraction).progressViewStyle(.linear).controlSize(.small)
                    .animation(Motion.progress, value: model.scanFraction)
                    .fadeTransition()
            }
            Divider()
            HStack(spacing: 6) {
                Picker(Loc.layout.s, selection: $layout) {
                    ForEach(LayoutMode.allCases) { Image(systemName: $0.symbol).help($0.title.s).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .disabled(!(model.pane ?? .overview).supportsGrid || model.isSearching)
                .help(Loc.layout.s)
                Spacer()
                Button { model.scan() } label: { Image(systemName: Symbols.rescan) }
                    .buttonStyle(.borderless)
                    .disabled(model.scanning)
                    .help(Loc.rescanHelp.s)
                SettingsLink { Image(systemName: Symbols.settings) }
                    .buttonStyle(.borderless)
                    .help(Loc.settings.s)
            }
        }
        .padding(Layout.rowSpacing)
    }

    /// One short line: spinner and percent while scanning, otherwise when it was measured.
    private var status: some View {
        HStack(spacing: 8) {
            if model.scanning {
                ProgressView().controlSize(.small)
                Text(Loc.scanningPercent.f(Fmt.percent(model.scanFraction))).monospacedDigit()
                    .contentTransition(.numericText(value: model.scanFraction))
                    .animation(Motion.progress, value: model.scanFraction)
            } else if let t = model.lastScan {
                Image(systemName: model.unreadable > 0 && !model.hasFullDiskAccess ? Symbols.warning : Symbols.success)
                    .foregroundStyle(model.unreadable > 0 && !model.hasFullDiskAccess ? .warn : .good)
                Text(Loc.measuredAt.f(Fmt.time(t)))
            } else {
                Image(systemName: Symbols.measure).foregroundStyle(.muted)
                Text(Loc.notMeasuredTitle.s)
            }
            Spacer(minLength: 0)
            Image(systemName: Symbols.info).foregroundStyle(.muted)
        }
        .font(.callout)
        .contentShape(Rectangle())
    }
}

/// Everything about the scan, shown only when asked for.
struct ScanDetails: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            Text(model.scanning ? Loc.scanningTitle.s : Loc.scanDetails.s).font(.headline)
            if model.scanning {
                ProgressView(value: model.scanFraction).progressViewStyle(.linear)
                    .animation(Motion.progress, value: model.scanFraction)
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
        .padding(Layout.cardPadding)
        .frame(width: Layout.popoverWidth)
    }
}
