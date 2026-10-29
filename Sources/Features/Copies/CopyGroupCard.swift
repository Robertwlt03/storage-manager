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
                UI.TitleRow(
                    group.appName, subtitle: group.bundleID, icon: .file(group.appPath ?? ""))
                Spacer()
                running
                    ? UI.Note(TextKey.running.translated, .warn(symbol: Symbols.running))
                    : UI.Note(TextKey.stopped.translated, .good(symbol: Symbols.stopped))
            }
            .padding(.vertical, Space.row)
            Divider()
            UI.Fields(fields)
            if let freed {
                Divider()
                UI.Note(
                    TextKey.freed.translated(with: Format.bytes(freed)),
                    .good(symbol: Symbols.success)
                )
                .padding(.vertical, Space.row)
            }
            if let error {
                Divider()
                UI.Note(error, .bad(symbol: Symbols.warning)).padding(.vertical, Space.row)
            }
            Divider()
            actions.padding(.vertical, Space.row)
        }
        .task(id: group.id) {
            running = CopyService.isRunning(group.bundleID)
            let g = group
            details = await Task.detached(priority: .utility) { CopyService.details(g) }.value
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didLaunchApplicationNotification)
        ) { _ in refreshRunning() }
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didTerminateApplicationNotification)
        ) { _ in refreshRunning() }
        .confirmationDialog(
            TextKey.deleteTitle.translated(with: Format.count(details?.count ?? 0), group.appName),
            isPresented: $confirming
        ) {
            Button(TextKey.deleteForever.translated, role: .destructive) { Task { await delete() } }
            Button(TextKey.cancel.translated, role: .cancel) {}
        } message: {
            Text(TextKey.deleteMessage.translated)
        }
    }

    private var fields: [UI.Field?] {
        var items: [UI.Field?] = [
            UI.Field(.copiesLabel, details.map { Format.count($0.count) }),
            UI.Field(.countedSize, Format.bytes(group.node.bytes)),
            UI.Field(.installedVersion, group.installedVersion ?? TextKey.notFound.translated),
        ]
        for v in details?.versions ?? [] {
            let state =
                v.version == group.installedVersion
                ? TextKey.current.translated : TextKey.old.translated
            items.append(
                UI.Field(
                    TextKey.versionLabel.translated(with: v.version),
                    Format.joined(Format.copies(v.count), state)))
        }
        for d in details?.days ?? [] {
            items.append(
                UI.Field(
                    TextKey.createdOn.translated(with: Format.day(d.day)), Format.copies(d.count)))
        }
        return items
    }

    private var actions: some View {
        HStack {
            if running {
                Text(TextKey.quitToDelete.translated(with: group.appName)).foregroundStyle(.warn)
            }
            Spacer()
            UI.ActionButton(TextKey.openInExplorer.translated) { model.open(group.node) }
            UI.ActionButton(TextKey.deleteAll.translated, role: .destructive) { confirming = true }
                .disabled(running || deleting || details == nil)
        }
    }

    private func refreshRunning() { running = CopyService.isRunning(group.bundleID) }

    private func delete() async {
        refreshRunning()  // checked again at the last moment
        guard !running else { return }
        deleting = true
        error = nil
        do { freed = try await model.delete(group) } catch {
            self.error = TextKey.deleteError.translated(with: error.localizedDescription)
        }
        deleting = false
    }
}
