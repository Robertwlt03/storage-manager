import SwiftUI

/// Apps not opened for a while, as a reminder that they still take up space; they can go to the Trash from here.
struct UnusedAppsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.unusedDays) private var days = CleanConfig.defaultUnusedDays
    @AppStorage(SettingsKey.layoutMode) private var layout = LayoutMode.list
    @State private var pending: AppUsage?
    @State private var error: String?

    private var unused: [AppUsage] {
        model.apps.filter { AppUsageService.isUnused($0, days: days) }
            .sorted { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
    }

    var body: some View {
        UI.Page(
            .apps,
            options: {
                UI.MenuPicker(.unusedSince, selection: $days) {
                    ForEach(CleanConfig.unusedDayOptions, id: \.self) {
                        Text(TextKey.daysOption.translated(with: Format.count($0))).tag($0)
                    }
                }
            }
        ) {
            if let error { UI.Note(error, .bad(symbol: Symbols.warning)) }
            if !model.hasData || model.apps.isEmpty {
                UI.Placeholder(.notMeasured, in: .page)
            } else if model.scanning {  // a running scan is about to replace sizes and dates
                UI.Card {
                    UI.Placeholder(
                        .loading(
                            title: .loadingAppsTitle, detail: .loadingAppsDetail,
                            symbol: Symbols.apps), in: .card)
                }
            } else if unused.isEmpty {
                UI.Placeholder(
                    .empty(title: TextKey.appsNoneUnused.translated, symbol: Symbols.success),
                    in: .page)
            } else if layout == .grid {
                UI.TileGrid(unused) { app in
                    UI.Tile(
                        icon: .file(app.path), title: app.name, value: Format.bytes(app.bytes),
                        detail: lastUsed(app)
                    )
                    .contextMenu { menu(app) }
                }
            } else {
                UI.Card {
                    UI.Rows(unused) { app in
                        HStack(spacing: Space.item) {
                            UI.Icon(.file(app.path))
                            VStack(alignment: .leading, spacing: Space.hairline) {
                                Text(app.name)
                                Text(lastUsed(app)).textRole(.hint)
                            }
                            Spacer(minLength: Space.item)
                            Text(Format.bytes(app.bytes)).textRole(.value)
                            UI.ActionButton(TextKey.showInFinder.translated) {
                                FinderService.reveal(app.path)
                            }
                            UI.ActionButton(TextKey.moveToTrash.translated, role: .destructive) {
                                pending = app
                            }
                            .disabled(AppUsageService.isRunning(app))
                        }
                        .contextMenu { menu(app) }
                    }
                }
            }
        }
        .confirmationDialog(
            TextKey.trashAppTitle.translated(with: pending?.name ?? ""),
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })
        ) {
            Button(TextKey.moveToTrash.translated, role: .destructive) { pending.map(trash) }
            Button(TextKey.cancel.translated, role: .cancel) {}
        } message: {
            Text(TextKey.trashAppMessage.translated)
        }
        .smoothChanges(of: layout)
    }

    @ViewBuilder private func menu(_ app: AppUsage) -> some View {
        Button(TextKey.showInFinder.translated) { FinderService.reveal(app.path) }
        Button(TextKey.moveToTrash.translated) { pending = app }
            .disabled(AppUsageService.isRunning(app))
    }

    private func lastUsed(_ app: AppUsage) -> String {
        app.lastUsed.map { TextKey.lastOpened.translated(with: Format.day($0)) }
            ?? TextKey.unknown.translated
    }

    private func trash(_ app: AppUsage) {
        error = nil
        do { try model.moveToTrash(app) } catch {
            self.error = TextKey.trashAppFailed.translated(with: app.name)
        }
        pending = nil
    }
}
