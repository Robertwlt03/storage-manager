import SwiftUI

/// Apps not opened for a while, as a reminder that they still take up space; they can go to the Trash from here.
struct UnusedAppsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.unusedDays) private var days = CleanConfig.defaultUnusedDays
    @AppStorage(SettingsKey.layoutMode) private var layout = LayoutMode.list
    @State private var pending: AppUsage?
    @State private var error: String?

    private var unused: [AppUsage] {
        model.apps.filter { AppUsageService.isUnused($0, days: days) }.sorted { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
    }

    var body: some View {
        UI.Page(.apps, options: {
            UI.MenuPicker(.unusedSince, selection: $days) {
                ForEach(CleanConfig.unusedDayOptions, id: \.self) { Text(Loc.daysOption.f(Fmt.count($0))).tag($0) }
            }
        }) {
            if let error { UI.Note(error, .bad(symbol: Symbols.warning)) }
            if !model.hasData || model.apps.isEmpty {
                UI.Placeholder(.notMeasured, in: .page)
            } else if model.scanning {  // a running scan is about to replace sizes and dates
                UI.Card {
                    UI.Placeholder(.loading(title: .loadingAppsTitle, detail: .loadingAppsDetail, symbol: Symbols.apps), in: .card)
                }
            } else if unused.isEmpty {
                UI.Placeholder(.empty(title: Loc.appsNoneUnused.s, symbol: Symbols.success), in: .page)
            } else if layout == .grid {
                UI.TileGrid(unused) { app in
                    UI.Tile(icon: .file(app.path), title: app.name, value: Fmt.bytes(app.bytes), detail: lastUsed(app))
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
                            Text(Fmt.bytes(app.bytes)).textRole(.value)
                            UI.ActionButton(Loc.showInFinder.s) { FinderService.reveal(app.path) }
                            UI.ActionButton(Loc.moveToTrash.s, role: .destructive) { pending = app }
                                .disabled(AppUsageService.isRunning(app))
                        }
                        .contextMenu { menu(app) }
                    }
                }
            }
        }
        .confirmationDialog(Loc.trashAppTitle.f(pending?.name ?? ""), isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button(Loc.moveToTrash.s, role: .destructive) { pending.map(trash) }
            Button(Loc.cancel.s, role: .cancel) {}
        } message: {
            Text(Loc.trashAppMessage.s)
        }
        .smoothChanges(of: layout)
    }

    @ViewBuilder private func menu(_ app: AppUsage) -> some View {
        Button(Loc.showInFinder.s) { FinderService.reveal(app.path) }
        Button(Loc.moveToTrash.s) { pending = app }.disabled(AppUsageService.isRunning(app))
    }

    private func lastUsed(_ app: AppUsage) -> String {
        app.lastUsed.map { Loc.lastOpened.f(Fmt.day($0)) } ?? Loc.unknown.s
    }

    private func trash(_ app: AppUsage) {
        error = nil
        do { try model.moveToTrash(app) } catch { self.error = Loc.trashAppFailed.f(app.name) }
        pending = nil
    }
}
