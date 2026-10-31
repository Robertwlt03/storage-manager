import SwiftUI

/// The available space of the startup volume in the menu bar, so it shows without opening the app;
/// a warning sign replaces the drive when space runs low.
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let volume = model.startupVolume {
                Label(
                    Format.bytes(volume.availableBytes),
                    systemImage: volume.isLow ? Symbols.lowSpace : Symbols.internalDrive
                )
                .labelStyle(.titleAndIcon)
                .accessibilityValue(volume.isLow ? TextKey.lowSpaceWarning.translated : "")
            } else {
                Image(systemName: Symbols.internalDrive)
                    .accessibilityLabel(TextKey.appName.translated)
            }
        }
        .task { await model.watchVolumes() }
    }
}

/// The menu under the menu bar item: the space in words, then opening the app, a new scan and
/// quitting.
struct MenuBarMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let volume = model.startupVolume {
            Text(
                TextKey.availableOf.translated(
                    with: Format.bytes(volume.availableBytes), Format.bytes(volume.totalBytes)))
            if volume.isLow { Text(TextKey.lowSpaceWarning.translated) }
            Divider()
        }
        Button(TextKey.openApp.translated(with: TextKey.appName.translated)) {
            openWindow(id: WindowID.main)
            NSApp.activate()
        }
        Button(TextKey.rescan.translated) { model.scan() }.disabled(model.isScanning)
        Divider()
        Button(TextKey.quitApp.translated(with: TextKey.appName.translated)) {
            LifecycleService.quit()
        }
    }
}
