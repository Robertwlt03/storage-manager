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
            Button {
                showDetails.toggle()
            } label: {
                status
            }
            .appButton(.content)
            .help(TextKey.scanDetails.translated)
            .popover(isPresented: $showDetails, arrowEdge: .trailing) { ScanDetails() }
            if model.scanning {
                ProgressView(value: model.scanFraction).progressViewStyle(.linear)
                    .controlSize(.small)
                    .animation(Motion.quick, value: model.scanFraction)
                    .fadeTransition()
            }
            Divider()
            HStack(spacing: Space.medium) {
                // One quiet button like the two next to it; the symbol shows what a click switches to.
                Button {
                    layout = layout == .list ? .grid : .list
                } label: {
                    UI.Icon(.symbol(layout == .list ? Symbols.grid : Symbols.list), size: .small)
                        .contentTransition(.symbolEffect(.replace))
                }
                .appButton(.quiet)
                .disabled(!(model.pane ?? .overview).supportsGrid || model.isSearching)
                .help(
                    layout == .list ? TextKey.layoutGrid.translated : TextKey.layoutList.translated
                )
                .accessibilityLabel(
                    layout == .list ? TextKey.layoutGrid.translated : TextKey.layoutList.translated)
                Spacer()
                Button {
                    model.scan()
                } label: {
                    UI.Icon(.symbol(Symbols.rescan), size: .small).turnOnce(value: scanStarts)
                }
                .appButton(.quiet)
                .disabled(model.scanning)
                .help(TextKey.rescanHelp.translated)
                SettingsLink { UI.Icon(.symbol(Symbols.settings), size: .small) }
                    .appButton(.quiet)
                    .help(TextKey.settings.translated)
            }
        }
        .padding(Space.item)
        .onChange(of: model.scanning) { if model.scanning { scanStarts += 1 } }
    }

    /// One short line: spinner and percent while scanning, otherwise when it was measured.
    private var status: some View {
        HStack(spacing: Space.small) {
            if model.scanning {
                // No spinner here: the progress bar right below already moves, and Apple prefers one determinate
                // indicator over a second endless one.
                UI.Icon(.symbol(Symbols.measure), size: .small).foregroundStyle(.tint)
                Text(TextKey.scanningPercent.translated(with: Format.percent(model.scanFraction)))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: model.scanFraction))
                    .animation(Motion.quick, value: model.scanFraction)
            } else if let t = model.lastScan {
                UI.Icon(
                    .symbol(
                        model.unreadable > 0 && !model.hasFullDiskAccess
                            ? Symbols.warning : Symbols.success),
                    size: .small
                )
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: t)  // a small nod when a scan has finished
                .foregroundStyle(model.unreadable > 0 && !model.hasFullDiskAccess ? .warn : .good)
                Text(TextKey.measuredAt.translated(with: Format.time(t)))
            } else {
                UI.Icon(.symbol(Symbols.measure), size: .small).foregroundStyle(.muted)
                Text(TextKey.notMeasuredTitle.translated)
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
            Text(model.scanning ? TextKey.scanningTitle.translated : TextKey.scanDetails.translated)
                .textRole(.section)
            if model.scanning {
                ProgressView(value: model.scanFraction).progressViewStyle(.linear)
                    .animation(Motion.quick, value: model.scanFraction)
                UI.Fields([
                    UI.Field(.scanProgress, Format.percent(model.scanFraction)),
                    UI.Field(
                        .scanArea,
                        TextKey.scanningArea.translated(
                            with: Format.count(model.scanStep.index),
                            Format.count(model.scanStep.count),
                            Paths.display(model.scanStep.path))),
                    UI.Field(
                        .files,
                        TextKey.filesAndSize.translated(
                            with: Format.count(model.progress.files),
                            Format.bytes(model.progress.bytes))),
                ])
                UI.ActionButton(TextKey.cancelScan.translated) { model.cancelScan() }
            } else {
                UI.Fields([
                    model.lastScan.map { UI.Field(.scanFinished, Format.time($0)) },
                    UI.Field(
                        .files,
                        TextKey.filesAndSize.translated(
                            with: Format.count(model.root.fileCount), Format.bytes(model.root.bytes)
                        )),
                    UI.Field(
                        .fullDiskAccess,
                        model.hasFullDiskAccess
                            ? TextKey.accessGranted.translated
                            : TextKey.accessMissingShort.translated),
                ])
                if model.unreadable > 0 && !model.hasFullDiskAccess {
                    UI.Note(TextKey.unreadable.translated(with: Format.count(model.unreadable)))
                    UI.ActionButton(TextKey.accessOpenSettings.translated, .primary) {
                        FinderService.openFullDiskAccessSettings()
                    }
                }
                UI.ActionButton(
                    model.lastScan == nil ? TextKey.scanNow.translated : TextKey.rescan.translated
                ) { model.scan() }
            }
        }
        .padding(Space.card)
        .frame(width: Layout.popoverWidth)
    }
}
