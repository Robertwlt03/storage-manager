import SwiftUI

/// Only what macOS does not already cover: appearance and units come from System Settings. The
/// language can follow the Mac or be picked here.
struct SettingsView: View {
    @AppStorage(SettingsKey.scansAutomatically) private var scansAtLaunch = true
    @AppStorage(SettingsKey.extraFolders) private var extraFolders = ""
    @State private var selectedFolder: String?
    @State private var language = AppLanguage.chosen

    var body: some View {
        Form {
            languagePicker
            Toggle(TextKey.autoScan.translated, isOn: $scansAtLaunch)
            LabeledContent(TextKey.extraFolders.translated) {
                folderEditor(AppSettings.folders(from: extraFolders))
            }
            Text(TextKey.settingsSystemNote.translated).textRole(.hint)
        }
        .formStyle(.grouped)
        .frame(width: Layout.settingsWidth, height: Layout.settingsHeight)
        .appLocale()
    }

    @ViewBuilder private var languagePicker: some View {
        UI.MenuPicker(.appLanguage, selection: $language, inForm: true) {
            Text(TextKey.languageLikeMac.translated).tag(AppLanguage?.none)
            ForEach(AppLanguage.byNativeName, id: \.self) { choice in
                Text(choice.nativeName).tag(AppLanguage?.some(choice))
            }
        }
        .onChange(of: language) { AppLanguage.choose(language) }
        if language != Localizer.shared.chosenAtLaunch {
            HStack {
                Text(TextKey.languageRestartHint.translated).textRole(.hint)
                Spacer()
                UI.ActionButton(TextKey.accessRestart.translated) { LifecycleService.relaunch() }
            }
        }
    }

    private func folderEditor(_ folders: [String]) -> some View {
        VStack(alignment: .leading, spacing: Space.small) {
            List(folders, id: \.self, selection: $selectedFolder) { folder in
                Text(Paths.displayName(folder)).lineLimit(1).truncationMode(.middle)
            }
            .frame(height: Layout.folderListHeight)
            .overlay {
                if folders.isEmpty { Text(TextKey.none.translated).textRole(.hint) }
            }
            folderButtons(folders)
        }
    }

    private func folderButtons(_ folders: [String]) -> some View {
        HStack(spacing: Space.extraSmall) {
            Button(TextKey.add.translated, systemImage: Symbols.add) {
                addChosenFolders(to: folders)
            }
            Button(TextKey.remove.translated, systemImage: Symbols.remove) {
                let remaining = folders.filter { folder in folder != selectedFolder }
                extraFolders = AppSettings.store(remaining)
            }
            .disabled(selectedFolder == nil)
        }
        .labelStyle(.iconOnly)
    }

    /// Adds the folders picked in the open panel; a folder already in the list stays once.
    private func addChosenFolders(to folders: [String]) {
        let allFolders = NSOrderedSet(array: folders + FinderService.chooseFolders())
        let withoutDuplicates = allFolders.array.compactMap { folder in folder as? String }
        extraFolders = AppSettings.store(withoutDuplicates)
    }
}
