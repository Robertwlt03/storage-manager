import SwiftUI

/// Bottom of the sidebar, always in the same place: a quiet scan status (details on click)
/// and the app-wide controls – list or grid, rescan and settings.
struct SidebarFooter: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.layoutMode) private var layout = LayoutMode.list
    @State private var isShowingDetails = false
    /// Turns the rescan symbol once when a scan starts (button or ⌘R; not at launch).
    @State private var scanStartCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Space.row) {
            statusButton
            if model.isScanning {
                ProgressView(value: model.scanFraction).progressViewStyle(.linear)
                    .controlSize(.small)
                    .animation(Motion.quick, value: model.scanFraction)
                    .fadeTransition()
            }
            Divider()
            HStack(spacing: Space.medium) {
                layoutButton
                Spacer()
                rescanButton
                SettingsLink { UI.Icon(.symbol(Symbols.settings), size: .small) }
                    .appButton(.quiet)
                    .help(TextKey.settings.translated)
            }
        }
        .padding(Space.item)
        .onChange(of: model.isScanning) { if model.isScanning { scanStartCount += 1 } }
    }

    private var statusButton: some View {
        Button {
            isShowingDetails.toggle()
        } label: {
            status
        }
        .appButton(.content)
        .help(TextKey.scanDetails.translated)
        .popover(isPresented: $isShowingDetails, arrowEdge: .trailing) { ScanDetails() }
    }

    /// One quiet button like the two next to it; the symbol shows what a click switches to.
    private var layoutButton: some View {
        let switchTitle =
            layout == .list ? TextKey.layoutGrid.translated : TextKey.layoutList.translated
        return Button {
            layout = layout == .list ? .grid : .list
        } label: {
            UI.Icon(.symbol(layout == .list ? Symbols.grid : Symbols.list), size: .small)
                .contentTransition(.symbolEffect(.replace))
        }
        .appButton(.quiet)
        .disabled(!(model.pane ?? .overview).supportsGrid || model.isSearching)
        .help(switchTitle)
        .accessibilityLabel(switchTitle)
    }

    private var rescanButton: some View {
        Button {
            model.scan()
        } label: {
            UI.Icon(.symbol(Symbols.rescan), size: .small).turnOnce(value: scanStartCount)
        }
        .appButton(.quiet)
        .disabled(model.isScanning)
        .help(TextKey.rescanHelp.translated)
    }

    /// One short line: spinner and percent while scanning, otherwise when it was measured.
    private var status: some View {
        HStack(spacing: Space.small) {
            if model.isScanning {
                // No spinner here: the progress bar right below already moves, and Apple prefers
                // one determinate indicator over a second endless one.
                UI.Icon(.symbol(Symbols.measure), size: .small).foregroundStyle(.tint)
                Text(TextKey.scanningPercent.translated(with: Format.percent(model.scanFraction)))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: model.scanFraction))
                    .animation(Motion.quick, value: model.scanFraction)
            } else if let lastScan = model.lastScan {
                finishedIcon(lastScan)
                Text(TextKey.measuredAt.translated(with: Format.time(lastScan)))
            } else {
                UI.Icon(.symbol(Symbols.measure), size: .small).foregroundStyle(.muted)
                Text(TextKey.notMeasuredTitle.translated)
            }
            Spacer(minLength: 0)
            UI.Icon(.symbol(Symbols.information), size: .small).foregroundStyle(.muted)
        }
        .textRole(.label)
        .contentShape(Rectangle())
    }

    @ViewBuilder private func finishedIcon(_ lastScan: Date) -> some View {
        let isMissingFolders = model.hasUnreadableFoldersWithoutAccess
        UI.Icon(.symbol(isMissingFolders ? Symbols.warning : Symbols.success), size: .small)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: lastScan)  // a small nod when a scan has finished
            .foregroundStyle(isMissingFolders ? .warning : .good)
    }
}

/// Everything about the scan, shown only when asked for.
private struct ScanDetails: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Space.item) {
            Text(
                model.isScanning ? TextKey.scanningTitle.translated : TextKey.scanDetails.translated
            )
            .textRole(.section)
            if model.isScanning {
                runningScan
            } else {
                finishedScan
            }
        }
        .padding(Space.card)
        .frame(width: Layout.popoverWidth)
    }

    @ViewBuilder private var runningScan: some View {
        let step = model.scanStep
        ProgressView(value: model.scanFraction).progressViewStyle(.linear)
            .animation(Motion.quick, value: model.scanFraction)
        UI.Fields([
            UI.Field(.scanProgress, Format.percent(model.scanFraction)),
            UI.Field(
                .scanArea,
                TextKey.scanningArea.translated(
                    with: Format.count(step.index), Format.count(step.count),
                    Paths.displayName(step.path))),
            UI.Field(
                .files,
                TextKey.filesAndSize.translated(
                    with: Format.count(model.progress.files), Format.bytes(model.progress.bytes))),
        ])
        UI.ActionButton(TextKey.cancelScan.translated) { model.cancelScan() }
    }

    @ViewBuilder private var finishedScan: some View {
        UI.Fields([
            model.lastScan.map { lastScan in UI.Field(.scanFinished, Format.time(lastScan)) },
            UI.Field(
                .files,
                TextKey.filesAndSize.translated(
                    with: Format.count(model.root.fileCount), Format.bytes(model.root.bytes))),
            UI.Field(
                .fullDiskAccess,
                model.hasFullDiskAccess
                    ? TextKey.accessGranted.translated : TextKey.accessMissingShort.translated),
        ])
        if model.hasUnreadableFoldersWithoutAccess {
            UI.Note(TextKey.unreadable.translated(with: Format.count(model.unreadableCount)))
            UI.ActionButton(TextKey.accessOpenSettings.translated, .primary) {
                FinderService.openFullDiskAccessSettings()
            }
        }
        UI.ActionButton(
            model.lastScan == nil ? TextKey.scanNow.translated : TextKey.rescan.translated
        ) { model.scan() }
    }
}

extension AppModel {
    fileprivate var hasUnreadableFoldersWithoutAccess: Bool {
        unreadableCount > 0 && !hasFullDiskAccess
    }
}
