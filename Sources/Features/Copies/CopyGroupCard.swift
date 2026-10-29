import AppKit
import SwiftUI

/// One app's copies: count, versions, dates and deleting them once the app is quit.
struct CopyGroupCard: View {
    let group: CopyGroup
    @Environment(AppModel.self) private var model
    @State private var details: CopyDetails?
    @State private var running = false
    @State private var confirming = false
    @State private var deleting = false
    @State private var freed: Int64?
    @State private var error: String?

    var body: some View {
        UI.Card {
            HStack {
                UI.TitleRow(group.appName, subtitle: group.bundleID, icon: .file(group.appPath ?? ""))
                Spacer()
                running ? UI.Note(Loc.running.s, .warn(symbol: Symbols.running)) : UI.Note(Loc.stopped.s, .good(symbol: Symbols.stopped))
            }
            .padding(.vertical, Space.row)
            Divider()
            UI.Fields(fields)
            if let freed { Divider(); UI.Note(Loc.freed.f(Fmt.bytes(freed)), .good(symbol: Symbols.success)).padding(.vertical, Space.row) }
            if let error { Divider(); UI.Note(error, .bad(symbol: Symbols.warning)).padding(.vertical, Space.row) }
            Divider()
            actions.padding(.vertical, Space.row)
        }
        .task(id: group.id) {
            running = CopyService.isRunning(group.bundleID)
            let g = group
            details = await Task.detached(priority: .utility) { CopyService.details(g) }.value
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in refreshRunning() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in refreshRunning() }
        .confirmationDialog(Loc.deleteTitle.f(Fmt.count(details?.count ?? 0), group.appName), isPresented: $confirming) {
            Button(Loc.deleteForever.s, role: .destructive) { Task { await delete() } }
            Button(Loc.cancel.s, role: .cancel) {}
        } message: {
            Text(Loc.deleteMessage.s)
        }
    }

    private var fields: [UI.Field?] {
        var items: [UI.Field?] = [UI.Field(.copiesLabel, details.map { Fmt.count($0.count) }),
                                   UI.Field(.countedSize, Fmt.bytes(group.node.bytes)),
                                   UI.Field(.installedVersion, group.installedVersion ?? Loc.notFound.s)]
        for v in details?.versions ?? [] {
            let state = v.version == group.installedVersion ? Loc.current.s : Loc.old.s
            items.append(UI.Field(Loc.versionLabel.f(v.version), Fmt.joined(Fmt.copies(v.count), state)))
        }
        for d in details?.days ?? [] { items.append(UI.Field(Loc.createdOn.f(Fmt.day(d.day)), Fmt.copies(d.count))) }
        return items
    }

    private var actions: some View {
        HStack {
            if running { Text(Loc.quitToDelete.f(group.appName)).foregroundStyle(.warn) }
            Spacer()
            UI.ActionButton(Loc.openInExplorer.s) { model.open(group.node) }
            UI.ActionButton(Loc.deleteAll.s, role: .destructive) { confirming = true }.disabled(running || deleting || details == nil)
        }
    }

    private func refreshRunning() { running = CopyService.isRunning(group.bundleID) }

    private func delete() async {
        refreshRunning()  // checked again at the last moment
        guard !running else { return }
        deleting = true
        error = nil
        do { freed = try await model.delete(group) } catch { self.error = Loc.deleteError.f(error.localizedDescription) }
        deleting = false
    }
}
