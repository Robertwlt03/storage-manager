import SwiftUI

/// Only what macOS does not already cover: appearance, language and units come from System Settings.
struct SettingsView: View {
    @AppStorage(SettingsKey.autoScan) private var autoScan = true
    @AppStorage(SettingsKey.extraFolders) private var extraFolders = ""
    @State private var selected: String?

    var body: some View {
        let folders = AppSettings.folders(from: extraFolders)
        Form {
            Toggle(Loc.autoScan.s, isOn: $autoScan)
            LabeledContent(Loc.extraFolders.s) {
                VStack(alignment: .leading, spacing: 6) {
                    List(folders, id: \.self, selection: $selected) { Text(Paths.display($0)).lineLimit(1).truncationMode(.middle) }
                        .frame(height: Layout.folderListHeight)
                        .overlay { if folders.isEmpty { Text(Loc.none.s).foregroundStyle(.muted) } }
                    HStack(spacing: 4) {
                        Button(Loc.add.s, systemImage: Symbols.add) {
                            extraFolders = AppSettings.store(Array(NSOrderedSet(array: folders + FinderService.chooseFolders()))
                                .compactMap { $0 as? String })
                        }
                        Button(Loc.remove.s, systemImage: Symbols.remove) {
                            extraFolders = AppSettings.store(folders.filter { $0 != selected })
                        }
                        .disabled(selected == nil)
                    }
                    .labelStyle(.iconOnly)
                }
            }
            Text(Loc.settingsSystemNote.s).foregroundStyle(.muted)
        }
        .formStyle(.grouped)
        .frame(width: Layout.settingsWidth, height: Layout.settingsHeight)
        .syncPreferences()
    }
}
