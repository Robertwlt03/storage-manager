import AppKit
import SwiftUI

/// One app's copies: count, versions, dates and deleting them once the app is quit.
struct CopyGroupCard: View {
    let group: CopyGroup
    @Environment(AppModel.self) private var model
    @State private var details: CopyDetails?
    @State private var isAppRunning = false
    @State private var isConfirming = false
    @State private var isDeleting = false
    @State private var freedBytes: Int64?
    @State private var errorMessage: String?

    var body: some View {
        UI.Card {
            header.padding(.vertical, Space.row)
            Divider()
            UI.Fields(fields)
            if let freedBytes {
                Divider()
                UI.Note.freed(freedBytes).padding(.vertical, Space.row)
            }
            if let errorMessage {
                Divider()
                UI.Note(errorMessage, .bad(symbol: Symbols.warning)).padding(.vertical, Space.row)
            }
            Divider()
            actions.padding(.vertical, Space.row)
        }
        .task(id: group.id) { await loadDetails() }
        .onReceive(appLaunches) { _ in refreshIsAppRunning() }
        .onReceive(appTerminations) { _ in refreshIsAppRunning() }
        .confirmRemoval(
            TextKey.deleteTitle.translated(
                with: Format.count(details?.copyCount ?? 0), group.appName),
            isPresented: $isConfirming, button: .deleteForever, message: .deleteMessage
        ) {
            Task { await deleteCopies() }
        }
    }

    private var header: some View {
        HStack {
            UI.TitleRow(group.appName, subtitle: group.bundleID, icon: .file(group.appPath ?? ""))
            Spacer()
            isAppRunning
                ? UI.Note(TextKey.running.translated, .warning(symbol: Symbols.running))
                : UI.Note(TextKey.stopped.translated, .good(symbol: Symbols.stopped))
        }
    }

    private var fields: [UI.Field?] { summaryFields + versionFields + dayFields }

    private var summaryFields: [UI.Field?] {
        [
            UI.Field(.copiesLabel, details.map { loaded in Format.count(loaded.copyCount) }),
            UI.Field(.countedSize, Format.bytes(group.node.bytes)),
            UI.Field(.installedVersion, group.installedVersion ?? TextKey.notFound.translated),
        ]
    }

    private var versionFields: [UI.Field?] {
        let versions = details?.versions ?? []
        return versions.map { version, count in
            let state =
                version == group.installedVersion
                ? TextKey.current.translated : TextKey.old.translated
            return UI.Field(
                TextKey.versionLabel.translated(with: version),
                Format.joined(Format.copies(count), state))
        }
    }

    private var dayFields: [UI.Field?] {
        let days = details?.days ?? []
        return days.map { day, count in
            UI.Field(TextKey.createdOn.translated(with: Format.day(day)), Format.copies(count))
        }
    }

    private var actions: some View {
        HStack {
            if isAppRunning {
                Text(TextKey.quitToDelete.translated(with: group.appName)).foregroundStyle(.warning)
            }
            Spacer()
            UI.ActionButton(TextKey.openInExplorer.translated) { model.open(group.node) }
            UI.ActionButton(TextKey.deleteAll.translated, role: .destructive) {
                isConfirming = true
            }
            .disabled(isAppRunning || isDeleting || details == nil)
        }
    }

    private var workspaceEvents: NotificationCenter { NSWorkspace.shared.notificationCenter }
    private var appLaunches: NotificationCenter.Publisher {
        workspaceEvents.publisher(for: NSWorkspace.didLaunchApplicationNotification)
    }
    private var appTerminations: NotificationCenter.Publisher {
        workspaceEvents.publisher(for: NSWorkspace.didTerminateApplicationNotification)
    }

    private func loadDetails() async {
        refreshIsAppRunning()
        let group = group
        details = await Task.detached(priority: .utility) { CopyService.details(group) }.value
    }

    private func refreshIsAppRunning() { isAppRunning = CopyService.isRunning(group.bundleID) }

    private func deleteCopies() async {
        refreshIsAppRunning()  // checked again at the last moment
        guard !isAppRunning else { return }
        isDeleting = true
        errorMessage = nil
        do { freedBytes = try await model.delete(group) } catch {
            errorMessage = TextKey.deleteError.translated(with: error.localizedDescription)
        }
        isDeleting = false
    }
}
