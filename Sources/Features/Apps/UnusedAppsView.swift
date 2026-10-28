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
        UI.page(.apps, options: {
            UI.menu(.unusedSince, selection: $days) {
                ForEach(CleanConfig.unusedDayOptions, id: \.self) { Text(Loc.daysOption.f(Fmt.count($0))).tag($0) }
            }
        }) {
            if let error { UI.status(error, symbol: Symbols.warning, .bad) }
            if !model.hasData || model.apps.isEmpty {
                UI.notMeasured()
            } else if unused.isEmpty {
                UI.empty(Loc.appsNoneUnused.s, symbol: Symbols.success)
            } else if layout == .grid {
                UI.grid(unused) { app in
                    UI.tile(icon: .file(app.path), title: app.name, value: Fmt.bytes(app.bytes), detail: lastUsed(app))
                        .contextMenu { menu(app) }
                }
            } else {
                UI.card {
                    UI.rows(unused) { app in
                        HStack(spacing: Space.item) {
                            RowIconView(icon: .file(app.path))
                            VStack(alignment: .leading, spacing: Space.hairline) {
                                Text(app.name)
                                Text(lastUsed(app)).font(.callout).foregroundStyle(.muted)
                            }
                            Spacer(minLength: Space.item)
                            Text(Fmt.bytes(app.bytes)).monospacedDigit().foregroundStyle(.muted)
                            UI.button(Loc.showInFinder.s) { FinderService.reveal(app.path) }
                            UI.button(Loc.moveToTrash.s, role: .destructive) { pending = app }
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
