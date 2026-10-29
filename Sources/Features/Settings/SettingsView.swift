import SwiftUI

/// Only what macOS does not already cover: appearance, language and units come from System Settings.
struct SettingsView: View {
    @AppStorage(SettingsKey.autoScan) private var autoScan = true
    @AppStorage(SettingsKey.extraFolders) private var extraFolders = ""
    @State private var selected: String?

    var body: some View {
        let folders = AppSettings.folders(from: extraFolders)
        Form {
            Toggle(TextKey.autoScan.translated, isOn: $autoScan)
            LabeledContent(TextKey.extraFolders.translated) {
                VStack(alignment: .leading, spacing: Space.small) {
                    List(folders, id: \.self, selection: $selected) {
                        Text(Paths.display($0)).lineLimit(1).truncationMode(.middle)
                    }
                    .frame(height: Layout.folderListHeight)
                    .overlay {
                        if folders.isEmpty { Text(TextKey.none.translated).textRole(.hint) }
                    }
                    HStack(spacing: Space.extraSmall) {
                        Button(TextKey.add.translated, systemImage: Symbols.add) {
                            extraFolders = AppSettings.store(
                                Array(NSOrderedSet(array: folders + FinderService.chooseFolders()))
                                    .compactMap { $0 as? String })
                        }
                        Button(TextKey.remove.translated, systemImage: Symbols.remove) {
                            extraFolders = AppSettings.store(folders.filter { $0 != selected })
                        }
                        .disabled(selected == nil)
                    }
                    .labelStyle(.iconOnly)
                }
            }
            Text(TextKey.settingsSystemNote.translated).textRole(.hint)
        }
        .formStyle(.grouped)
        .frame(width: Layout.settingsWidth, height: Layout.settingsHeight)
        .syncPreferences()
    }
}
