import AppKit
import SwiftUI

/// One app's copies: how much space they take, whether they can go now, one button to delete
/// them once the app is quit, and the versions and dates folded away below.
struct CopyGroupCard: View {
    let group: CopyGroup
    @Environment(AppModel.self) private var model
    @State private var details: CopyDetails?
    @State private var isAppRunning: Bool
    @State private var isConfirming = false
    @State private var isDeleting = false
    @State private var freedBytes: Int64?
    @State private var errorMessage: String?

    /// Knows from the first frame whether the app runs, so the card never calls it closed by
    /// mistake.
    init(group: CopyGroup) {
        self.group = group
        _isAppRunning = State(initialValue: CopyService.isRunning(group.bundleID))
    }

    var body: some View {
        UI.Card {
            header.padding(.vertical, Space.row)
            if let freedBytes {
                Divider()
                UI.Note.freed(freedBytes).padding(.vertical, Space.row)
            }
            if let errorMessage {
                Divider()
                UI.Note(errorMessage, .bad(symbol: Symbols.warning)).padding(.vertical, Space.row)
            }
            Divider()
            technicalDetails.padding(.vertical, Space.row)
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
        HStack(spacing: Space.item) {
            UI.Icon(.file(group.appPath ?? ""), size: .large)
            VStack(alignment: .leading, spacing: Space.hairline) {
                Text(group.appName).textRole(.title).lineLimit(Layout.maximumWrappedLines)
                advice
            }
            Spacer(minLength: Space.item)
            UI.ActionButton(TextKey.deleteAll.translated, role: .destructive) {
                isConfirming = true
            }
            .disabled(isAppRunning || isDeleting || details == nil)
        }
    }

    /// What the copies take up and whether they can go right now.
    private var advice: some View {
        let size = Format.bytes(group.node.bytes)
        let text = isAppRunning ? TextKey.quitToDelete : .copiesSafeToDelete
        let style =
            isAppRunning
            ? UI.Note.Style.warning(symbol: Symbols.running) : .good(symbol: Symbols.stopped)
        return UI.Note(text.translated(with: size, group.appName), style)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Versions, dates and the way to the folder, folded away for the curious.
    private var technicalDetails: some View {
        DisclosureGroup(TextKey.technicalDetails.translated) {
            VStack(alignment: .leading, spacing: 0) {
                UI.Fields(fields)
                openInExplorerButton.padding(.vertical, Space.row)
            }
        }
    }

    private var openInExplorerButton: some View {
        HStack {
            Spacer()
            UI.ActionButton(TextKey.openInExplorer.translated) { model.open(group.node) }
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

    private var workspaceEvents: NotificationCenter { NSWorkspace.shared.notificationCenter }
    private var appLaunches: NotificationCenter.Publisher {
        workspaceEvents.publisher(for: NSWorkspace.didLaunchApplicationNotification)
    }
    private var appTerminations: NotificationCenter.Publisher {
        workspaceEvents.publisher(for: NSWorkspace.didTerminateApplicationNotification)
    }

    private func loadDetails() async {
        refreshIsAppRunning()
        details = await model.copyDetails(of: group)
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
