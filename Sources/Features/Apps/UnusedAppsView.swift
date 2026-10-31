import SwiftUI

/// Apps not opened for a while, as a reminder that they still take up space; they can go to the
/// Trash from here.
struct UnusedAppsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.unusedDays) private var unusedDays = CleanUpRules.defaultUnusedDays
    @AppStorage(SettingsKey.layoutMode) private var layout = LayoutMode.list
    @State private var appToTrash: AppUsage?
    @State private var errorMessage: String?

    private var unusedApps: [AppUsage] { AppUsageService.unused(model.apps, days: unusedDays) }

    var body: some View {
        UI.Page(.apps, options: { options }, content)
            .confirmRemoval(
                TextKey.trashAppTitle.translated(with: appToTrash?.name ?? ""),
                item: $appToTrash, button: .moveToTrash, message: .trashAppMessage,
                action: moveToTrash
            )
            .smoothChanges(of: layout)
    }

    @ViewBuilder private var options: some View {
        LayoutSwitcher(pane: .apps)
        unusedSincePicker
    }

    private var unusedSincePicker: some View {
        UI.MenuPicker(.unusedSince, selection: $unusedDays) {
            ForEach(CleanUpRules.unusedDayOptions, id: \.self) { days in
                Text(TextKey.daysOption.translated(with: Format.count(days))).tag(days)
            }
        }
    }

    @ViewBuilder private func content() -> some View {
        if let errorMessage { UI.Note(errorMessage, .bad(symbol: Symbols.warning)) }
        if !model.hasData || model.apps.isEmpty {
            UI.Placeholder(.notMeasured, in: .page)
        } else if model.isScanning {
            // A running scan is about to replace sizes and dates.
            UI.Card {
                UI.Placeholder(
                    .loading(
                        title: .loadingAppsTitle, detail: .loadingAppsDetail, symbol: Symbols.apps),
                    in: .card)
            }
        } else if unusedApps.isEmpty {
            UI.Placeholder(
                .empty(
                    title: TextKey.appsNoneUnused.translated, symbol: Symbols.success,
                    detail: TextKey.appsNoneUnusedDetail.translated),
                in: .page)
        } else if layout == .grid {
            UI.TileGrid(unusedApps) { app in tile(app) }
        } else {
            UI.Card {
                UI.Rows(unusedApps) { app in row(app) }
            }
        }
    }

    private func tile(_ app: AppUsage) -> some View {
        UI.Tile(
            icon: .file(app.path), title: app.name, value: Format.bytes(app.bytes),
            detail: lastOpenedText(app)
        )
        .contextMenu { contextMenu(app) }
    }

    private func row(_ app: AppUsage) -> some View {
        HStack(spacing: Space.item) {
            UI.Icon(.file(app.path))
            VStack(alignment: .leading, spacing: Space.hairline) {
                Text(app.name)
                Text(lastOpenedText(app)).textRole(.hint)
            }
            Spacer(minLength: Space.item)
            Text(Format.bytes(app.bytes)).textRole(.value)
            UI.ActionButton(TextKey.showInFinder.translated, .inline) {
                FinderService.reveal(app.path)
            }
            UI.ActionButton(TextKey.moveToTrash.translated, .inline, role: .destructive) {
                appToTrash = app
            }
            .disabled(AppUsageService.isRunning(app))
        }
        .contextMenu { contextMenu(app) }
    }

    @ViewBuilder private func contextMenu(_ app: AppUsage) -> some View {
        Button(TextKey.showInFinder.translated) { FinderService.reveal(app.path) }
        Button(TextKey.moveToTrash.translated, role: .destructive) { appToTrash = app }
            .disabled(AppUsageService.isRunning(app))
    }

    private func lastOpenedText(_ app: AppUsage) -> String {
        guard let lastUsed = app.lastUsed else { return TextKey.unknown.translated }
        return TextKey.lastOpened.translated(with: Format.day(lastUsed))
    }

    private func moveToTrash(_ app: AppUsage) {
        errorMessage = nil
        do { try model.moveToTrash(app) } catch {
            errorMessage = TextKey.trashAppFailed.translated(with: app.name)
        }
        appToTrash = nil
    }
}
